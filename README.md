# Automação de Provisionamento e Backup Local usando PowerShell e Hyper‑V

Repositório com os scripts desenvolvidos no Trabalho de Conclusão de Curso  
**“Automação de Provisionamento e Backup Local usando PowerShell e Hyper‑V: um estudo sobre ferramentas de infraestrutura como código”**, apresentado ao curso de Ciência da Computação da Universidade Paulista (UNIP).

O objetivo deste projeto é propor e demonstrar um modelo de automação para criação, cópia e restauração de máquinas virtuais em ambiente local, utilizando apenas ferramentas nativas do ecossistema Microsoft. A solução foi construída sobre o Hyper‑V como hipervisor e o PowerShell como camada de automação, aplicando princípios de Infraestrutura como Código (IaC) em um cenário on‑premises.

---

## 1. Contexto do projeto

Em muitos ambientes que utilizam Hyper‑V, tarefas como criação de máquinas virtuais, configuração de recursos e realização de backups continuam sendo executadas manualmente pela interface gráfica. Esse modelo, embora funcional, tende a ser mais lento, sujeito a erros de configuração e pouco padronizado.

A proposta deste repositório é registrar, de forma versionada, os scripts que automatizam essas atividades, permitindo:

- provisionar máquinas virtuais com parâmetros padronizados por script;
- executar backups completos de VMs de forma recorrente, com registro em log;
- restaurar ambientes a partir dos backups gerados, com processo documentado.

O repositório complementa o texto do TCC, funcionando como “documentação executável” da solução descrita no trabalho.

---

## 2. Tecnologias utilizadas

- **Sistema operacional hospedeiro:** Windows 10 Pro (compatível com Hyper‑V)  
- **Hipervisor:** Hyper‑V (função nativa do Windows)  
- **Ambiente de automação:** PowerShell 7.4  
- **Ferramentas de apoio:**
  - Hyper‑V Manager (validação pontual das configurações)
  - Visualizador de Eventos do Windows (verificação de logs do sistema)
  - 7‑Zip (opcional, para compactação de backups)

Os testes descritos no TCC foram realizados em um equipamento com processador Intel Core i5 ultra 235u, 16 GB de RAM e SSD de 512 GB, o que permitiu avaliar desempenho e estabilidade em um cenário próximo ao uso real.

---

## 3. Estrutura do repositório

```text
hyperv-powershell-automation/
│
├── README.md                 # Visão geral do projeto e contextualização
├── .gitignore                # Arquivos ignorados pelo controle de versão
│
├── scripts/
│   ├── provisionamento/
│   │   └── Create-VM.ps1     # Script de criação automatizada de máquinas virtuais
│   └── backup/
│       └── Backup-VM.ps1     # Script de backup local automatizado de VMs
│
├── logs/
│   └── .gitkeep              # Pasta de destino sugerida para arquivos de log
│
└── docs/
    └── como-usar.md          # Guia de execução e parametrização dos scripts
```

Os caminhos dos scripts seguem exatamente a estrutura mencionada nos apêndices do TCC, o que facilita a consulta cruzada entre documentação acadêmica e código.

---

## 4. Pré‑requisitos

Antes de executar os scripts, recomenda‑se verificar os seguintes itens:

1. **Windows 10 Pro ou Windows Server** com o recurso Hyper‑V habilitado.  
2. **PowerShell 7.4** instalado e configurado.  
3. **Módulo do Hyper‑V** disponível no PowerShell:

   ```powershell
   Get-Module -ListAvailable Hyper-V
   ```

4. **Execução em contexto administrativo**: o PowerShell deve ser aberto como administrador.  
5. **Política de execução** ajustada para permitir scripts locais:

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

6. **Switch virtual do Hyper‑V** previamente criado (por exemplo, `RedeExterna`), conforme descrito no capítulo de desenvolvimento do TCC.

---

## 5. Scripts disponíveis

### 5.1 Script de provisionamento – `Create-VM.ps1`

Local: `scripts/provisionamento/Create-VM.ps1`

Responsável por automatizar a criação de uma máquina virtual no Hyper‑V, a partir de parâmetros informados pelo administrador. Em linhas gerais, o script:

- recebe nome da VM, caminho da ISO, diretório base, memória, tamanho do disco e switch de rede;
- cria o diretório da máquina virtual, com base no padrão definido;
- gera o disco virtual em formato VHDX (alocação dinâmica);
- cria a VM no Hyper‑V, associa o disco e configura memória e CPU;
- vincula o adaptador de rede ao switch escolhido;
- anexa a mídia de instalação (ISO) como unidade de DVD;
- inicia a VM e registra o resultado em um arquivo de log.

A estrutura geral do script reproduz o que é descrito no Apêndice A do TCC, com a diferença de que aqui o código aparece completo e versionado, permitindo acompanhamento de ajustes e correções.

### 5.2 Script de backup local – `Backup-VM.ps1`

Local: `scripts/backup/Backup-VM.ps1`

Implementa a rotina de backup local automatizado, conforme detalhado no Apêndice B. O fluxo básico inclui:

- recebimento do nome da VM e do diretório base de backups;
- criação de uma pasta identificada por data e hora para cada execução;
- verificação do estado da máquina virtual (ligada, desligada, salva);
- desligamento controlado da VM quando necessário, para garantir consistência;
- exportação completa da VM por meio do cmdlet `Export-VM`;
- religamento da máquina após a conclusão da exportação;
- registro de sucesso ou falha em arquivo de log.

O script foi pensado para ser integrado ao Agendador de Tarefas do Windows, viabilizando execuções recorrentes sem intervenção manual constante.

---

## 6. Guia rápido de uso

Um guia passo a passo, com exemplos de execução e orientações práticas, está disponível em [`docs/como-usar.md`](docs/como-usar.md). De forma resumida:

- para criar uma nova VM, utiliza‑se o script `Create-VM.ps1` com os parâmetros desejados;
- para gerar um backup, utiliza‑se o script `Backup-VM.ps1`, indicando o nome da VM e o diretório de destino.

As chamadas de exemplo e os detalhes de cada parâmetro são descritos no arquivo de documentação mencionado.

---

## 7. Relação com o TCC

Este repositório foi organizado para complementar o trabalho escrito, permitindo que o leitor:

- consulte o código completo dos scripts apresentados de forma resumida nos apêndices;
- acompanhe a estrutura de diretórios proposta para armazenamento de VMs, backups e logs;
- visualize, na prática, os conceitos de automação e IaC discutidos ao longo dos capítulos.

Dessa forma, o repositório não apenas ilustra a solução desenvolvida, mas também funciona como base para reprodução dos experimentos em outros ambientes e para estudos posteriores sobre automação de infraestrutura local com PowerShell e Hyper‑V.
