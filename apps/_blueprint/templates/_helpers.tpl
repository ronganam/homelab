{{- define "app.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
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
