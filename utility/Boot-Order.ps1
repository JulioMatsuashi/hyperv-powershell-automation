<#
.SYNOPSIS
    Redefine a ordem de boot de uma VM existente para inicializar pelo DVD.

.DESCRIPTION
    Script complementar ao Create-VM.ps1, desenvolvido como parte do Trabalho
    de Conclusão de Curso "Automação de Provisionamento e Backup Local usando
    PowerShell e Hyper-V".

    Para uso quando a VM já foi criada mas não iniciou pela mídia de instalação.
    O script para a VM, recupera automaticamente o ISO já vinculado ao drive de
    DVD da máquina informada (sem necessidade de informar o path da ISO),
    redefine a ordem de boot para DVD e reinicia a máquina.

.PARAMETER VMName
    Nome da máquina virtual alvo. Deve existir no host Hyper-V local.

.EXAMPLE
    .\Boot-Order.ps1 -VMName "ServidorTeste01"

    Para a VM, define o DVD como primeiro dispositivo de boot e reinicia.

.NOTES
    Requisitos de ambiente:
      - PowerShell 7.4 ou superior
      - Módulo Hyper-V instalado e habilitado
      - Console iniciado com privilégios de Administrador

    Autor: Julio Hideki Moreira Matsuashi
    TCC — Ciência da Computação — UNIP — 2025
    Repositório: https://github.com/seu-usuario/hyperv-powershell-automation
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$VMName
)

# =============================================================================
# BLOCO 1 — VALIDAÇÃO
#
# Antes de executar qualquer operação, o script verifica se a VM informada
# existe no host Hyper-V local e se possui um drive de DVD com ISO vinculado.
# Caso alguma das condições não seja atendida, a execução é interrompida com
# uma mensagem clara, evitando alterações em máquinas incorretas.
# =============================================================================

Write-Host "Verificando a VM '$VMName'..."

$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "Erro: nenhuma VM com o nome '$VMName' foi encontrada no host local."
    exit 1
}

$dvd = Get-VMDvdDrive -VMName $VMName -ErrorAction SilentlyContinue
if (-not $dvd) {
    Write-Host "Erro: nenhum drive de DVD encontrado na VM '$VMName'."
    Write-Host "Verifique se o ISO foi vinculado via Create-VM.ps1 ou manualmente."
    exit 1
}

if (-not $dvd.Path) {
    Write-Host "Aviso: o drive de DVD existe, mas nenhum ISO está vinculado."
    Write-Host "Vincule um ISO antes de redefinir a ordem de boot."
    exit 1
}

Write-Host "ISO detectado: $($dvd.Path)"

# =============================================================================
# BLOCO 2 — PARAR A VM
#
# A alteração de firmware só é permitida com a VM desligada. O parâmetro
# -Force encerra a máquina imediatamente sem aguardar o desligamento gracioso
# do sistema operacional, o que é adequado para o ambiente de testes.
# =============================================================================

Write-Host "Parando a VM '$VMName'..."
Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
Write-Host "VM parada."

# =============================================================================
# BLOCO 3 — REDEFINIR ORDEM DE BOOT
#
# O firmware da VM (UEFI / Geração 2) é atualizado para que o drive de DVD
# seja o primeiro dispositivo de inicialização. O ISO já vinculado ao drive
# é mantido sem alteração, dispensando o path como parâmetro.
# =============================================================================

Write-Host "Redefinindo ordem de boot para DVD na VM '$VMName'..."
try {
    Set-VMFirmware `
        -VMName $VMName `
        -FirstBootDevice (Get-VMDvdDrive -VMName $VMName) `
        -ErrorAction Stop

    Write-Host "Ordem de boot redefinida: DVD como primeiro dispositivo de inicialização."
}
catch {
    Write-Host "Erro ao redefinir a ordem de boot: $($_.Exception.Message)"
    exit 1
}

# =============================================================================
# BLOCO 4 — INICIAR A VM
#
# Com o firmware atualizado, a VM é iniciada. O boot ocorrerá pelo DVD,
# exibindo a tela de instalação do sistema operacional contido na ISO.
# =============================================================================

Write-Host "Iniciando a VM '$VMName'..."
try {
    Start-VM -Name $VMName -ErrorAction Stop
    Write-Host "VM '$VMName' iniciada com sucesso."
    Write-Host "Acompanhe a instalação pelo Hyper-V Manager > Conectar."
}
catch {
    Write-Host "Erro ao iniciar a VM: $($_.Exception.Message)"
    exit 1
}
