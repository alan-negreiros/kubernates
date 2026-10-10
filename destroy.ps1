foreach ($n in 1..3) {
    Write-Host "==> Removendo o Desafio $n" -ForegroundColor Cyan
    kubectl delete namespace "desafio-$n" --ignore-not-found
    kubectl delete pv "postgres-pv-desafio-$n" --ignore-not-found
}
