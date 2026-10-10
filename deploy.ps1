param(
    [switch]$SkipBuild,
    [switch]$SkipMetricsServer
)

$desafios = 1..3
$metricsServerUrl = 'https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml'

function Invoke-Native {
    param([string]$Description, [scriptblock]$Command)
    Write-Host "==> $Description" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Falhou: $Description (código $LASTEXITCODE)" }
}

Invoke-Native 'Verificando o acesso ao cluster' { kubectl cluster-info }

if (-not $SkipBuild) {
    foreach ($n in $desafios) {
        Invoke-Native "Construindo a imagem desafio-$n-api:1.0.0" {
            docker build -t "desafio-$n-api:1.0.0" (Join-Path $PSScriptRoot "Desafio $n")
        }
    }
}

if (-not $SkipMetricsServer) {
    $metricsServer = kubectl get deployment metrics-server -n kube-system --ignore-not-found -o name
    if ($metricsServer) {
        Write-Host '==> Metrics Server já instalado' -ForegroundColor Cyan
    } else {
        Invoke-Native 'Instalando o Metrics Server' { kubectl apply -f $metricsServerUrl }
        Invoke-Native 'Ajustando o Metrics Server para cluster local' {
            kubectl patch deployment metrics-server -n kube-system --type=json --patch-file (Join-Path $PSScriptRoot 'cluster\metrics-server-patch.yaml')
        }
    }
}

foreach ($n in $desafios) {
    Invoke-Native "Aplicando os manifestos do Desafio $n" {
        kubectl apply -f (Join-Path $PSScriptRoot "Desafio $n\k8s")
    }
    if (-not $SkipBuild) {
        Invoke-Native "Reiniciando a API do Desafio $n" {
            kubectl rollout restart deployment/api-deployment -n "desafio-$n"
        }
    }
}

foreach ($n in $desafios) {
    Invoke-Native "Aguardando o PostgreSQL do Desafio $n" {
        kubectl rollout status deployment/postgres-deployment -n "desafio-$n" --timeout=300s
    }
    Invoke-Native "Aguardando a API do Desafio $n" {
        kubectl rollout status deployment/api-deployment -n "desafio-$n" --timeout=300s
    }
}

foreach ($n in $desafios) {
    Write-Host "`n--- desafio-$n ---" -ForegroundColor Green
    kubectl get pods,svc,hpa,pvc -n "desafio-$n"
}

Write-Host "`nAPIs disponíveis:" -ForegroundColor Green
Write-Host '  Desafio 1: http://localhost:8081/health  |  http://localhost:8081/api/users'
Write-Host '  Desafio 2: http://localhost:8082/db-test |  http://localhost:8082/users'
Write-Host '  Desafio 3: http://localhost:8083/        |  http://localhost:8083/users'
