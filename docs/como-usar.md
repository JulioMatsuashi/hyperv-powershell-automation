# Guia de utilização dos scripts

Este documento descreve as etapas necessárias para executar os scripts
de automação desenvolvidos neste projeto. As instruções foram utilizadas
durante os testes práticos descritos no TCC e podem ser adaptadas a outros
ambientes compatíveis com Windows e Hyper-V.

---

## 1. Configuração inicial do ambiente

Antes de executar qualquer script, verifique os seguintes pré-requisitos:

1. O recurso **Hyper-V** deve estar habilitado nas Funcionalidades do Windows.
2. Um **switch virtual externo** deve estar criado no Hyper-V Manager com o nome `RedeExterna`.
3. O **PowerShell 7.4** deve estar instalado. A política de execução deve permitir scripts locais:

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. Os diretórios padrão utilizados pelos scripts podem ser criados antecipadamente:

   ```powershell
   New-Item -ItemType Directory -Force -Path "C:\HyperV\VMs"     | Out-Null
   New-Item -ItemType Directory -Force -Path "C:\HyperV\Backups" | Out-Null
   New-Item -ItemType Directory -Force -Path "C:\HyperV\Logs"    | Out-Null
   ```

5. Todos os scripts devem ser executados em console de PowerShell aberto
   com **permissões de Administrador**.

---

## 2. Criação de máquina virtual

Script: `scripts/provisionamento/Create-VM.ps1`

Exemplo de execução:

```powershell
.\scripts\provisionamento\Create-VM.ps1 `
    -VMName   "ServidorTeste01" `
    -ISOPath  "C:\ISOs\WindowsServer2022.iso" `
    -VMPath   "C:\HyperV\VMs" `
    -MemoryGB 2
```

Após a execução:

- A máquina virtual será listada no Hyper-V Manager.
- O disco virtual VHDX estará em `C:\HyperV\VMs\ServidorTeste01\`.
- O log da operação estará em `C:\HyperV\Logs\CreateVM_data_hora.log`.
- A instalação do sistema operacional pode ser acompanhada pelo Hyper-V Manager
  utilizando a opção de conexão à VM (VMConnect).

---

## 3. Backup local de máquina virtual

Script: `scripts/backup/Backup-VM.ps1`

Exemplo de execução:

```powershell
.\scripts\backup\Backup-VM.ps1 `
    -VMName     "ServidorTeste01" `
    -BackupRoot "C:\HyperV\Backups"
```

Após a execução:

- Os arquivos da VM exportada estarão em um subdiretório no formato
  `C:\HyperV\Backups\ServidorTeste01_YYYYMMDD_HHMM\`.
- O log da operação estará em `C:\HyperV\Logs\Backup_ServidorTeste01_YYYYMMDD_HHMM.log`.
- Se a VM estiver em execução no momento do backup, será desligada
  de forma controlada antes da exportação e religada ao término.

---

## 4. Agendamento automático de backups

Para que os backups sejam executados automaticamente sem intervenção manual,
integre o script ao Agendador de Tarefas do Windows:

1. Abra o **Agendador de Tarefas** (`taskschd.msc`).
2. Clique em **Criar Tarefa**.
3. Na aba **Geral**, defina um nome e marque **Executar com privilégios mais altos**.
4. Na aba **Disparadores**, adicione um novo disparador com a periodicidade desejada
   (por exemplo, diariamente às 02:00).
5. Na aba **Ações**, configure:
   - **Programa:** `pwsh.exe`
   - **Argumentos:**
     ```
     -NonInteractive -File "C:\hyperv-powershell-automation\scripts\backup\Backup-VM.ps1" -VMName "ServidorTeste01" -BackupRoot "C:\HyperV\Backups"
     ```
6. Salve a tarefa e verifique sua execução na próxima janela agendada.

---

## 5. Verificação dos logs

Todos os logs são gravados automaticamente em `C:\HyperV\Logs\`.
Cada execução gera um arquivo separado, identificado pelo tipo de operação,
nome da VM e timestamp, por exemplo:
