# Guia de utilização dos scripts

Este documento descreve as etapas necessárias para executar os scripts
de automação desenvolvidos neste projeto. As instruções foram utilizadas
durante os testes práticos descritos no TCC e podem ser adaptadas a outros
ambientes compatíveis com Windows e Hyper-V.

---

## 1. Configuração inicial do ambiente

Antes de executar qualquer script, alguns pré-requisitos precisam estar
atendidos no ambiente host.

1. O recurso **Hyper-V** deve estar habilitado nas Funcionalidades do Windows.

2. Um **switch virtual externo** deve estar criado no Hyper-V Manager com o
   nome exato:

   ```text
   RedeExterna
   ```

3. O **PowerShell 7** deve estar instalado via **MSI** — não pela Microsoft
   Store nem pelo winget. A instalação via Store coloca o executável dentro de
   uma pasta cujo nome muda a cada atualização de versão, o que quebra o
   agendamento de tarefas. O instalador MSI garante que o executável sempre
   esteja em:

   ```text
   C:\Program Files\PowerShell\7\pwsh.exe
   ```

   O instalador oficial pode ser baixado na página de releases do PowerShell:

   ```text
   https://github.com/PowerShell/PowerShell/releases/latest
   ```

   Baixe o arquivo com extensão `.msi` para Windows x64, por exemplo:

   ```text
   PowerShell-7.x.x-win-x64.msi
   ```

   Execute o instalador e conclua com as opções padrão. Não é necessário
   desinstalar versões anteriores instaladas pela Store — as duas coexistem
   sem conflito.

4. Após a instalação, a política de execução deve permitir scripts locais.
   Execute o comando abaixo no PowerShell como Administrador:

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

5. Os diretórios utilizados pelos scripts podem ser criados antecipadamente.
   **Atenção:** os caminhos padrão definidos nos scripts usam as unidades
   `C:` e `D:`. Dependendo do ambiente, pode ser necessário ajustar esses
   caminhos antes de executar. Verifique em cada script qual unidade está
   sendo utilizada e adapte conforme a estrutura de discos disponível.

   Exemplo criando os diretórios no disco `D:`:

   ```powershell
   New-Item -ItemType Directory -Force -Path "C:\HyperV\VMs"     | Out-Null
   New-Item -ItemType Directory -Force -Path "C:\HyperV\Backups" | Out-Null
   New-Item -ItemType Directory -Force -Path "C:\HyperV\Logs"    | Out-Null
   ```

   Os logs são gravados em `C:\HyperV\Logs` por padrão, independentemente
   de onde as VMs e backups estejam armazenados.

6. Todos os scripts devem ser executados em um console de PowerShell aberto
   com **permissões de Administrador**.

---

## 2. Criação de máquina virtual

Script: `scripts/provisionamento/Create-VM.ps1`

Este script automatiza a criação completa de uma VM no Hyper-V, incluindo
a criação do diretório, geração do disco VHDX dinâmico, configuração de
memória estática, definição da quantidade de processadores virtuais,
conexão ao switch e vinculação da mídia de instalação.

### Parâmetros

| Parâmetro        | Obrigatório | Padrão          | Descrição                              |
|------------------|-------------|-----------------|----------------------------------------|
| `-VMName`        | Sim         | —               | Nome da máquina virtual                |
| `-ISOPath`       | Sim         | —               | Caminho completo do arquivo ISO        |
| `-VMPath`        | Não         | `C:\HyperV\VMs` | Diretório base das VMs                 |
| `-MemoryGB`      | Não         | `2`             | RAM em gigabytes                       |
| `-ProcessorCount`| Não         | `2`             | Quantidade de processadores virtuais   |

### Exemplo de execução

```powershell
.\scripts\provisionamento\Create-VM.ps1 `
    -VMName          "ServidorTeste01" `
    -ISOPath         "C:\ISOs\WindowsServer2022.iso" `
    -VMPath          "C:\HyperV\VMs" `
    -MemoryGB        4 `
    -ProcessorCount  4
```

Adapte `-VMPath` e `-ISOPath` para o disco correto do seu ambiente
(`C:` ou `D:`).

Após a execução:

- A VM aparecerá listada no Hyper-V Manager.
- O disco VHDX estará em `C:\HyperV\VMs\ServidorTeste01\ServidorTeste01.vhdx`.
- O log da operação estará em `C:\HyperV\Logs\CreateVM_<data_hora>.log`.
- A instalação do sistema operacional pode ser acompanhada pelo Hyper-V
  Manager usando a opção de conexão à VM (VMConnect).

---

## 3. Backup local de máquina virtual

Script: `scripts/backup/Backup-VM.ps1`

Este script realiza a exportação completa de uma VM para um diretório de
backup organizado por timestamp. Se a VM estiver em execução, ela é
desligada de forma controlada antes da exportação e religada ao término.

### Parâmetros

| Parâmetro     | Obrigatório | Padrão              | Descrição                        |
|---------------|-------------|---------------------|----------------------------------|
| `-VMName`     | Sim         | —                   | Nome da VM a ser exportada       |
| `-BackupRoot` | Não         | `C:\HyperV\Backups` | Diretório raiz dos backups       |

### Exemplo de execução

```powershell
.\scripts\backup\Backup-VM.ps1 `
    -VMName     "ServidorTeste01" `
    -BackupRoot "C:\HyperV\Backups"
```

Adapte `-BackupRoot` para o disco utilizado no seu ambiente.

Após a execução:

- Os arquivos exportados estarão em:

  ```text
  C:\HyperV\Backups\ServidorTeste01_YYYYMMDD_HHmm\
  ```

- O log da operação estará em:

  ```text
  C:\HyperV\Logs\Backup_ServidorTeste01_YYYYMMDD_HHmm.log
  ```

---

## 4. Verificação dos logs

Todos os logs são gravados automaticamente em:

```text
C:\HyperV\Logs\
```

Cada execução gera um arquivo separado identificado pelo tipo de operação,
nome da VM e timestamp. Exemplos:

- Criação de VM:

  ```text
  CreateVM_15-04-2026_02-00.log
  ```

- Backup de VM:

  ```text
  Backup_ServidorTeste01_20260415_0200.log
  ```

- Registro de tarefa agendada:

  ```text
  RegisterTask_20260415_0200.log
  ```

Esses arquivos foram utilizados no TCC para registrar as execuções de
teste e facilitar o diagnóstico em caso de falhas.

---

## 5. Scripts auxiliares — pasta `utility`

A pasta `utility` contém dois scripts complementares que automatizam
etapas que, sem eles, exigiriam configuração manual no Hyper-V Manager
ou no Agendador de Tarefas.

---

### 5.1. Ajuste da ordem de boot — `Boot-Order.ps1`

Script: `utility/Boot-Order.ps1`

Quando uma VM é criada pelo `Create-VM.ps1` e não inicializa pela mídia
de instalação — exibindo a tela de PXE IPv4 ou iniciando em disco vazio —
este script corrige a ordem de boot do firmware da VM para que o DVD
(ISO) seja o primeiro dispositivo de inicialização.

O script para a VM se estiver ligada, localiza o drive de DVD já
configurado e redefine a ordem de boot sem que seja necessário abrir o
Hyper-V Manager.

#### Exemplo de execução

```powershell
.\utility\Boot-Order.ps1 -VMName "ServidorTeste01"
```

Após a execução, a VM será reiniciada e deve exibir a tela de instalação
do sistema operacional.

---

### 5.2. Agendamento automático de backup — `Register-BackupTask.ps1`

Script: `utility/Register-BackupTask.ps1`

Cria uma tarefa no Agendador de Tarefas do Windows para executar o
`Backup-VM.ps1` automaticamente todos os dias às 02:00, utilizando o
PowerShell 7. A tarefa é registrada para rodar com a conta SYSTEM e com
privilégios elevados, dispensando a necessidade de um usuário autenticado
no momento da execução.

**Atenção:** este script depende do PowerShell 7 instalado via MSI.
Se o PowerShell 7 foi instalado pela Microsoft Store ou pelo winget,
o caminho do executável será diferente e o script retornará erro de
validação. Consulte a seção 1.3 deste guia para instruções de instalação
via MSI.

#### Parâmetros

| Parâmetro      | Obrigatório | Padrão                                                        | Descrição                              |
|----------------|-------------|---------------------------------------------------------------|----------------------------------------|
| `-VMName`      | Sim         | —                                                             | Nome da VM cujo backup será agendado   |
| `-ScriptPath`  | Não         | `C:\hyperv-powershell-automation\scripts\backup\Backup-VM.ps1`| Caminho do script de backup            |
| `-BackupRoot`  | Não         | `C:\HyperV\Backups`                                           | Diretório raiz dos backups             |
| `-TaskName`    | Não         | `Backup-VM-<VMName>`                                          | Nome da tarefa no Agendador            |

#### Exemplo de execução

```powershell
.\utility\Register-BackupTask.ps1 `
    -VMName     "ServidorTeste01" `
    -ScriptPath "C:\hyperv-powershell-automation\scripts\backup\Backup-VM.ps1" `
    -BackupRoot "C:\HyperV\Backups"
```

Adapte `-ScriptPath` para o caminho real do repositório no seu ambiente
e `-BackupRoot` para o disco utilizado (`C:` ou `D:`).

Após a execução:

- Uma tarefa chamada `Backup-VM-ServidorTeste01` será criada no
  Agendador de Tarefas e pode ser visualizada em `taskschd.msc`.
- O backup passará a ser executado automaticamente todos os dias às 02:00.
- Um log de registro da tarefa será gravado em:

  ```text
  C:\HyperV\Logs\RegisterTask_YYYYMMDD_HHmm.log
  ```
