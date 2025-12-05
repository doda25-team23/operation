{{/*
Expand the name of the chart.
*/}}
{{- define "sms-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sms-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "sms-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sms-app.labels" -}}
helm.sh/chart: {{ include "sms-app.chart" . }}
{{ include "sms-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sms-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sms-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "sms-app.frontend.selectorLabels" -}}
app: {{ .Values.frontend.service.name }}
{{ include "sms-app.selectorLabels" . }}
{{- end }}

{{/*
Model service selector labels
*/}}
{{- define "sms-app.modelService.selectorLabels" -}}
app: {{ .Values.modelService.service.name }}
{{ include "sms-app.selectorLabels" . }}
{{- end }}

{{/*
Frontend service name
*/}}
{{- define "sms-app.frontend.serviceName" -}}
{{- printf "%s-%s" (include "sms-app.fullname" .) .Values.frontend.service.name }}
{{- end }}

{{/*
Model service name
*/}}
{{- define "sms-app.modelService.serviceName" -}}
{{- printf "%s-%s" (include "sms-app.fullname" .) .Values.modelService.service.name }}
{{- end }}

{{/*
Construct the MODEL_HOST URL dynamically
*/}}
{{- define "sms-app.modelServiceUrl" -}}
{{- printf "http://%s:%d" (include "sms-app.modelService.serviceName" .) (int .Values.modelService.service.port) }}
{{- end }}
