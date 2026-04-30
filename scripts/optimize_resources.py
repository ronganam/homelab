#!/usr/bin/env python3
import os
import json
import requests
import argparse
from ruamel.yaml import YAML

# Standard Kubernetes resource optimization script
# Logic:
# - CPU Request: 110% of max usage (min 10m)
# - Memory Request: 110% of max usage (min 16Mi)
# - Memory Limit: 130% of max usage
# - CPU Limit: REMOVED

def format_cpu(value):
    m_cores = int(value * 1000)
    return f"{max(m_cores, 10)}m"

def format_mem(value):
    mib = int(value / (1024 * 1024))
    return f"{max(mib, 16)}Mi"

def get_metrics(url, token, lookback_hrs):
    headers = {"Authorization": f"Bearer {token}"}
    lookback = f"{lookback_hrs}h"
    
    # 1. Find Prometheus datasource ID
    ds_resp = requests.get(f"{url}/api/datasources", headers=headers)
    ds_resp.raise_for_status()
    datasources = ds_resp.json()
    prom_ds = next((ds for ds in datasources if ds['type'] == 'prometheus'), None)
    if not prom_ds:
        raise Exception("Prometheus datasource not found in Grafana")
    
    ds_id = prom_ds['id']
    proxy_url = f"{url}/api/datasources/proxy/{ds_id}/api/v1/query"
    
    def query_prom(q):
        resp = requests.get(proxy_url, headers=headers, params={'query': q})
        resp.raise_for_status()
        return resp.json()['data']['result']

    # CPU query
    cpu_q = f'max_over_time(rate(container_cpu_usage_seconds_total{{container!="", pod!="", namespace!~"kube-system|monitoring|argocd"}}[5m])[{lookback}:1h])'
    # Mem query
    mem_q = f'max_over_time(container_memory_working_set_bytes{{container!="", pod!="", namespace!~"kube-system|monitoring|argocd"}}[{lookback}:1h])'
    
    cpu_results = query_prom(cpu_q)
    mem_results = query_prom(mem_q)
    
    usage = {}
    for item in cpu_results:
        ns = item['metric']['namespace']
        cont = item['metric']['container']
        usage.setdefault((ns, cont), {})['cpu'] = float(item['value'][1])
        
    for item in mem_results:
        ns = item['metric']['namespace']
        cont = item['metric']['container']
        usage.setdefault((ns, cont), {})['mem'] = float(item['value'][1])
        
    return usage

def update_resources(resources_node, cpu_val, mem_val):
    if not resources_node:
        resources_node = {}
    
    # Update requests
    requests = resources_node.get('requests', {})
    requests['cpu'] = format_cpu(cpu_val * 1.1)
    requests['memory'] = format_mem(mem_val * 1.1)
    resources_node['requests'] = requests
    
    # Update limits
    limits = resources_node.get('limits', {})
    limits['memory'] = format_mem(mem_val * 1.3)
    # Remove CPU limit
    if 'cpu' in limits:
        del limits['cpu']
    
    if limits:
        resources_node['limits'] = limits
    elif 'limits' in resources_node:
        del resources_node['limits']
        
    return resources_node

def process_file(fpath, ns, container_name, cpu_val, mem_val):
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    
    with open(fpath, 'r') as f:
        docs = list(yaml.load_all(f))
    
    modified = False
    new_docs = []
    
    for data in docs:
        if not data:
            new_docs.append(data)
            continue
            
        doc_modified = False
        # Case 1: Deployment or StatefulSet
        if isinstance(data, dict) and data.get('kind') in ['Deployment', 'StatefulSet']:
            containers = data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            for cont in containers:
                if cont.get('name') == container_name:
                    cont['resources'] = update_resources(cont.get('resources', {}), cpu_val, mem_val)
                    doc_modified = True
                    modified = True
                    
        # Case 2: Helm values.yaml
        elif fpath.endswith('values.yaml'):
            # Try to find common locations for resources
            # 1. Top level
            if 'resources' in data:
                data['resources'] = update_resources(data['resources'], cpu_val, mem_val)
                doc_modified = True
                modified = True
            # 2. Under container name or app name
            for key in [container_name, container_name.replace('-ngx', ''), container_name.split('-')[-1]]:
                if key in data and isinstance(data[key], dict) and 'resources' in data[key]:
                    data[key]['resources'] = update_resources(data[key]['resources'], cpu_val, mem_val)
                    doc_modified = True
                    modified = True
            # 3. Special cases for bitnami-style charts (Postgres/Redis)
            if container_name in ['postgresql', 'redis', 'mariadb']:
                for key in ['primary', 'master', 'auth']: # bitnami pattern
                    if container_name in data and isinstance(data[container_name], dict) and key in data[container_name] and isinstance(data[container_name][key], dict) and 'resources' in data[container_name][key]:
                         data[container_name][key]['resources'] = update_resources(data[container_name][key]['resources'], cpu_val, mem_val)
                         doc_modified = True
                         modified = True
                if container_name in data and isinstance(data[container_name], dict) and 'resources' in data[container_name]:
                     data[container_name]['resources'] = update_resources(data[container_name]['resources'], cpu_val, mem_val)
                     doc_modified = True
                     modified = True
        new_docs.append(data)

    if modified:
        with open(fpath, 'w') as f:
            yaml.dump_all(new_docs, f)
        print(f"Updated {fpath} (container: {container_name})")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.getenv("GRAFANA_URL", "https://grafana.ganam.app"))
    parser.add_argument("--token", default=os.getenv("GRAFANA_TOKEN"))
    parser.add_argument("--lookback", type=int, default=48)
    args = parser.parse_args()
    
    if not args.token:
        print("Error: GRAFANA_TOKEN is required")
        return

    usage = get_metrics(args.url, args.token, args.lookback)
    
    apps_dir = "apps"
    for ns_cont, vals in usage.items():
        ns, cont = ns_cont
        cpu = vals.get('cpu', 0)
        mem = vals.get('mem', 0)
        
        # Match namespace to app directory
        app_path = os.path.join(apps_dir, ns)
        if not os.path.isdir(app_path):
            # Fallback: try to find which app directory contains this namespace
            # (In this repo, usually app name == namespace)
            continue
            
        for fname in ['deployment.yaml', 'statefulset.yaml', 'values.yaml']:
            fpath = os.path.join(app_path, fname)
            if os.path.exists(fpath):
                process_file(fpath, ns, cont, cpu, mem)

if __name__ == "__main__":
    main()
