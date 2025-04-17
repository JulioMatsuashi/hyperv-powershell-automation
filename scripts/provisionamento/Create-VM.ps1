<#
.SYNOPSIS
    Automatiza a criação de máquinas virtuais no Hyper-V.

.DESCRIPTION
    Script desenvolvido como parte do Trabalho de Conclusão de Curso
    "Automação de Provisionamento e Backup Local usando PowerShell e Hyper-V".

    O script recebe parâmetros de configuração e executa, em sequência,
    a criação do diretório da máquina virtual, a geração do disco virtual
    em formato VHDX, a criação e configuração da VM no Hyper-V, a vinculação
    da mídia de instalação e a inicialização da máquina. Cada etapa é
    registrada em arquivo de log com timestamp.

    Estrutura do script (conforme Apêndice A do TCC):
      Bloco 1 — Definição de parâmetros e variáveis de ambiente
      Bloco 2 — Preparação de diretórios e disco virtual
      Bloco 3 — Criação e configuração da máquina virtual
      Bloco 4 — Inicialização da máquina e registro em log

.PARAMETER VMName
    Nome da máquina virtual a ser criada. Deve ser único no host Hyper-V.

.PARAMETER ISOPath
    Caminho completo para o arquivo ISO do sistema operacional.
    Exemplo: "C:\ISOs\WindowsServer2022.iso"

.PARAMETER VMPath
    Diretório raiz onde as máquinas virtuais serão armazenadas.
    Padrão: C:\HyperV\VMs

.PARAMETER MemoryGB
    Quantidade de memória RAM, em gigabytes, alocada para a VM.
    Padrão: 2 GB

.EXAMPLE
    .\Create-VM.ps1 -VMName "ServidorTeste01" -ISOPath "C:\ISOs\WS2022.iso"

    Cria a VM com os valores padrão: 2 GB de RAM, disco de 60 GB, 1 processador virtual.

.EXAMPLE
    .\Create-VM.ps1 -VMName "ServidorWeb01" -ISOPath "C:\ISOs\WS2022.iso" -MemoryGB 4 -VMPath "D:\VMs"

    Cria a VM com 4 GB de RAM no diretório D:\VMs.

.NOTES
    Requisitos de ambiente:
      - PowerShell 7.4 ou superior
      - Módulo Hyper-V instalado e habilitado
      - Console iniciado com privilégios de Administrador
      - Switch virtual "RedeExterna" criado previamente no Hyper-V Manager

    Autor: Julio Hideki Moreira Matsuashi
    TCC — Ciência da Computação — UNIP — 2025
    Repositório: https://github.com/seu-usuario/hyperv-powershell-automation
#>

param (
    [string]$VMName,
    [string]$ISOPath,
    [string]$VMPath   = "C:\HyperV\VMs",
    [int]   $MemoryGB = 2
)

# =============================================================================
# BLOCO 1 — DEFINIÇÃO DE PARÂMETROS E VARIÁVEIS DE AMBIENTE
#
# Antes de qualquer operação, o script define o caminho do arquivo de log
# com base na data e hora da execução. Esse arquivo registra cada etapa
# realizada, permitindo auditoria posterior e diagnóstico de falhas.
# =============================================================================

$Date    = Get-Date -Format "dd-MM-yyyy_HH-mm"
$LogDir  = "C:\HyperV\Logs"
$LogFile = "$LogDir\CreateVM_$Date.log"

# Garante que o diretório de logs existe antes de tentar gravar nele
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Write-Log {
    <#
    .SYNOPSIS
        Grava uma mensagem no console e no arquivo de log, com timestamp.
    .DESCRIPTION
        Centralizar o registro de mensagens em uma função garante formato
        consistente em todas as entradas do log, independentemente de onde
        no script a mensagem for gerada.
    #>
    param([string]$Message)
    $entrada = "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] $Message"
    Write-Host $entrada
    Add-Content -Path $LogFile -Value $entrada
}

Write-Log "Iniciando criação da máquina virtual: $VMName"
Write-Log "Parâmetros recebidos — Memória: $($MemoryGB)GB | Diretório base: $VMPath | ISO: $ISOPath"

# =============================================================================
# BLOCO 2 — PREPARAÇÃO DE DIRETÓRIOS E DISCO VIRTUAL
#
# Cada VM recebe um diretório próprio dentro do diretório base informado.
# O disco virtual é criado em formato VHDX com alocação dinâmica, ou seja,
# o arquivo cresce conforme dados são gravados, o que economiza espaço físico
# durante os testes. O tamanho máximo foi fixado em 60 GB, conforme o
# ambiente definido na metodologia do trabalho.
# =============================================================================

$VMDir   = "$VMPath\$VMName"
$VHDPath = "$VMDir\$VMName.vhdx"

Write-Log "Criando diretório da VM em: $VMDir"
New-Item -ItemType Directory -Force -Path $VMDir | Out-Null

Write-Log "Criando disco virtual VHDX dinâmico de 60 GB em: $VHDPath"
try {
    New-VHD -Path $VHDPath -SizeBytes 60GB -Dynamic -ErrorAction Stop | Out-Null
    Write-Log "Disco virtual criado com sucesso."
}
catch {
    Write-Log "Falha ao criar o disco virtual: $($_.Exception.Message)"
    exit 1
}

# =============================================================================
# BLOCO 3 — CRIAÇÃO E CONFIGURAÇÃO DA MÁQUINA VIRTUAL
#
# A VM é criada como Geração 2 (UEFI), compatível com Windows Server 2012 R2
# e versões posteriores. Após a criação, o disco virtual é associado e a
# mídia de instalação (ISO) é vinculada como unidade de DVD.
#
# Em VMs de Geração 2, a unidade de DVD não existe por padrão e precisa ser
# adicionada explicitamente antes de definir o caminho da imagem ISO.
#
# A memória é configurada como estática, sem balanceamento dinâmico, o que
# garante comportamento previsível e facilita a comparação de desempenho
# entre execuções distintas durante os testes.
# =============================================================================

Write-Log "Criando a máquina virtual '$VMName' no Hyper-V (Geração 2)..."
try {
    New-VM -Name $VMName `
           -MemoryStartupBytes ($MemoryGB * 1GB) `
           -Path $VMPath `
           -Generation 2 `
           -SwitchName "RedeExterna" `
           -ErrorAction Stop | Out-Null

    Write-Log "Máquina virtual criada com sucesso."
}
catch {
    Write-Log "Falha ao criar a máquina virtual: $($_.Exception.Message)"
    exit 1
}

# Associa o disco virtual VHDX à VM recém-criada
Write-Log "Associando disco virtual à VM..."
try {
    Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath -ErrorAction Stop
    Write-Log "Disco virtual associado."
}
catch {
    Write-Log "Falha ao associar o disco virtual: $($_.Exception.Message)"
    exit 1
}

# Configura memória como estática
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false -StartupBytes ($MemoryGB * 1GB)
Write-Log "Memória configurada: $($MemoryGB) GB (estática)."

# Adiciona a unidade de DVD e vincula a ISO de instalação
Write-Log "Configurando mídia de instalação (ISO)..."
try {
    Add-VMDvdDrive -VMName $VMName -ErrorAction Stop
    $dvd = Get-VMDvdDrive -VMName $VMName

    Set-VMDvdDrive -VMName $VMName `
                   -ControllerNumber   $dvd.ControllerNumber `
                   -ControllerLocation $dvd.ControllerLocation `
                   -Path $ISOPath `
                   -ErrorAction Stop

    Write-Log "Mídia de instalação configurada: $ISOPath"
}
catch {
    Write-Log "Falha ao configurar a mídia de instalação: $($_.Exception.Message)"
}

# =============================================================================
# BLOCO 4 — INICIALIZAÇÃO DA MÁQUINA E REGISTRO EM LOG
#
# Com todos os recursos configurados, a VM é iniciada. A partir deste ponto,
# o Hyper-V realizará o boot pelo DVD e exibirá a tela de instalação do
# sistema operacional. O administrador pode acompanhar o processo pelo
# Hyper-V Manager utilizando a opção de conexão à VM (VMConnect).
# =============================================================================

Write-Log "Iniciando a máquina virtual '$VMName'..."
try {
    Start-VM -Name $VMName -ErrorAction Stop
    Write-Log "Máquina virtual '$VMName' iniciada com sucesso."
}
catch {
    Write-Log "Falha ao iniciar a máquina virtual: $($_.Exception.Message)"
    exit 1
}

Add-Content $LogFile "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] Máquina $VMName criada e iniciada com sucesso."

Write-Log "------------------------------------------------------------"
Write-Log "Provisionamento concluído. Log disponível em: $LogFile"
Write-Log "Para acessar a VM, utilize o Hyper-V Manager > Conectar."
Write-Log "------------------------------------------------------------"
