{{- define "app.name" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "app.namespace" -}}
{{ .Release.Namespace }}
{{- end -}}

{{- define "app.labels" -}}
app: {{ include "app.name" . }}
{{- end -}}

{{- define "app.selectorLabels" -}}
app: {{ include "app.name" . }}
{{- end -}}
