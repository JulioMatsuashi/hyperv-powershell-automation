<#
.SYNOPSIS
    Automatiza o backup local de máquinas virtuais no Hyper-V.

.DESCRIPTION
    Script desenvolvido como parte do Trabalho de Conclusão de Curso
    "Automação de Provisionamento e Backup Local usando PowerShell e Hyper-V".

    O script realiza a exportação completa de uma máquina virtual para um
    diretório de backup organizado por data e hora. Antes de iniciar a
    exportação, verifica o estado da VM e, caso esteja em execução, realiza
    o desligamento controlado para garantir a consistência dos arquivos
    exportados. Ao término, a máquina é reiniciada e o resultado da
    operação é registrado em log.

    Estrutura do script (conforme Apêndice B do TCC):
      Bloco 1 — Definição de parâmetros e preparação de diretórios
      Bloco 2 — Verificação do estado da máquina virtual
      Bloco 3 — Exportação da máquina virtual
      Bloco 4 — Religamento da máquina e registro em log

.PARAMETER VMName
    Nome da máquina virtual a ser copiada. Deve existir no Hyper-V local.

.PARAMETER BackupRoot
    Diretório raiz onde os backups serão armazenados. Para cada execução,
    um subdiretório com o nome da VM e o timestamp da operação é criado
    automaticamente, evitando sobrescrita de backups anteriores.
    Padrão: C:\HyperV\Backups

.EXAMPLE
    .\Backup-VM.ps1 -VMName "ServidorTeste01"

    Executa o backup com o diretório padrão C:\HyperV\Backups.

.EXAMPLE
    .\Backup-VM.ps1 -VMName "ServidorTeste01" -BackupRoot "C:\Backups"

    Executa o backup armazenando os arquivos no disco D:.

.NOTES
    Para agendar este script no Agendador de Tarefas do Windows:
      Programa : pwsh.exe
      Argumentos: -File "C:\scripts\backup\Backup-VM.ps1" -VMName "ServidorTeste01"
      Executar como: Administrador

    Autor: Julio Hideki Moreira Matsuashi
    TCC — Ciência da Computação — UNIP — 2025
    Repositório: https://github.com/seu-usuario/hyperv-powershell-automation
#>

param (
    [string]$VMName,
    [string]$BackupRoot = "C:\HyperV\Backups"
)

# =============================================================================
# BLOCO 1 — DEFINIÇÃO DE PARÂMETROS E PREPARAÇÃO DE DIRETÓRIOS
#
# Cada execução gera um subdiretório identificado pelo nome da VM e pelo
# timestamp no formato YYYYMMDD_HHMM. Essa convenção garante que backups
# de diferentes momentos coexistam sem risco de sobrescrita, facilitando
# também a identificação visual das versões disponíveis.
# =============================================================================

$Date      = Get-Date -Format "yyyyMMdd_HHmm"
$BackupDir = Join-Path $BackupRoot "$VMName`_$Date"
$LogDir    = "C:\HyperV\Logs"
$LogFile   = "$LogDir\Backup_$VMName`_$Date.log"

foreach ($dir in @($BackupDir, $LogDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Grava uma mensagem no console e no arquivo de log, com timestamp.
    #>
    param([string]$Message)
    $entrada = "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] $Message"
    Write-Host $entrada
    Add-Content -Path $LogFile -Value $entrada
}

Write-Log "Iniciando backup da máquina virtual: $VMName"
Write-Log "Destino do backup: $BackupDir"

# =============================================================================
# BLOCO 2 — VERIFICAÇÃO DO ESTADO DA MÁQUINA VIRTUAL
#
# Exportar uma VM em execução pode gerar um disco em estado inconsistente,
# equivalente ao que ocorreria em um desligamento abrupto de um servidor
# físico. Por isso, o script verifica o estado atual da máquina antes de
# prosseguir: se estiver ligada, realiza desligamento controlado; se já
# estiver desligada ou em estado salvo, avança diretamente para a exportação.
# =============================================================================

try {
    $vm = Get-VM -Name $VMName -ErrorAction Stop
}
catch {
    Write-Log "Máquina virtual '$VMName' não encontrada neste host. Encerrando."
    exit 1
}

Write-Log "Estado atual da VM: $($vm.State)"

$estaLigada = $false

if ($vm.State -eq 'Running') {
    Write-Log "VM em execução. Realizando desligamento controlado antes da exportação..."
    Stop-VM -Name $VMName -Force
    $estaLigada = $true

    # Aguarda desligamento completo com verificação a cada 5 segundos
    while ((Get-VM -Name $VMName).State -ne 'Off') {
        Start-Sleep -Seconds 5
    }
    Write-Log "VM desligada com sucesso."
}
elseif ($vm.State -eq 'Saved') {
    Write-Log "VM em estado salvo. O estado será preservado no backup."
}
elseif ($vm.State -eq 'Off') {
    Write-Log "VM já desligada. Prosseguindo para exportação."
}

# =============================================================================
# BLOCO 3 — EXPORTAÇÃO DA MÁQUINA VIRTUAL
#
# O cmdlet Export-VM copia todos os arquivos da VM — configuração XML,
# disco(s) VHDX e eventuais checkpoints — para o diretório de backup.
# O resultado é um conjunto completo de arquivos que pode ser importado
# em qualquer host Hyper-V compatível por meio do cmdlet Import-VM.
#
# Em caso de falha na exportação, o script registra a exceção em log e,
# se a VM estava em execução antes do backup, tenta religá-la para não
# deixar o ambiente parado desnecessariamente.
# =============================================================================

Write-Log "Iniciando exportação da VM '$VMName' para: $BackupDir"

try {
    Export-VM -Name $VMName -Path $BackupDir -ErrorAction Stop
    Write-Log "Exportação concluída com sucesso."
}
catch {
    Write-Log "Falha durante a exportação: $($_.Exception.Message)"

    if ($estaLigada) {
        Write-Log "Tentando religar a VM após falha na exportação..."
        Start-VM -Name $VMName -ErrorAction SilentlyContinue
    }

    Add-Content $LogFile "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] Falha no backup de $VMName`: $($_.Exception.Message)"
    exit 1
}

# =============================================================================
# BLOCO 4 — RELIGAMENTO DA MÁQUINA E REGISTRO EM LOG
#
# Após a exportação bem-sucedida, a VM é religada caso estivesse em execução
# antes do início do backup. Esse comportamento reduz o impacto da rotina
# de backup sobre a disponibilidade do ambiente.
#
# O script registra o resultado final da operação, indicando o caminho do
# backup gerado e o arquivo de log correspondente.
# =============================================================================

if ($estaLigada) {
    Write-Log "Religando a VM '$VMName' após o backup..."
    try {
        Start-VM -Name $VMName -ErrorAction Stop
        Write-Log "VM '$VMName' religada com sucesso."
    }
    catch {
        Write-Log "Falha ao religar a VM: $($_.Exception.Message)"
        Write-Log "A VM precisará ser iniciada manualmente."
    }
}
else {
    Write-Log "VM estava desligada antes do backup. Estado mantido: desligada."
}

Add-Content $LogFile "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] Backup concluído com sucesso para $VMName em $BackupDir."

Write-Log "------------------------------------------------------------"
Write-Log "Backup concluído. Arquivos disponíveis em: $BackupDir"
Write-Log "Log registrado em: $LogFile"
Write-Log "------------------------------------------------------------"
