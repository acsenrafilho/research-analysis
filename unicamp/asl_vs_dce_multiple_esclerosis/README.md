# ASL vs DCE - Multiple Sclerosis

## Importante: dados fora do repositório Git

Este projeto foi organizado para manter apenas código, documentação e pipelines dentro do repositório.
Os dados de imagem brutos e processados devem ficar em um diretório local do computador, fora do Git, por exemplo:

- /home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/data/EM
- /home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/analysis/asl_vs_dce_multiple_sclerosis

A estrutura do repositório será usada apenas para scripts, configuração e documentação. Nenhuma imagem .nii, .nii.gz, .dcm, .zip ou resultado gerado deve ser versionado.

## Objetivo do estudo

Comparar a permeabilidade da barreira hematoencefálica (BHE) estimada por ASL sem contraste com a permeabilidade derivada de ressonância dinâmica com gadolínio (DCE-MRI / modelagem farmacocinética) em pacientes com esclerose múltipla.

O estudo será estruturado como uma avaliação metodológica e translacional, com foco em concordância espacial e sensibilidade de detecção entre os dois métodos, tanto em análise voxel a voxel quanto em regiões de interesse e máscaras de lesão.

---

## Racional científico

- A ruptura da BHE é um mecanismo central na patogênese da EM e na formação de lesões inflamatórias.
- O padrão de referência para avaliação de permeabilidade vascular é a modelagem farmacocinética de DCE-MRI com gadolínio, frequentemente expressa em parâmetros como $K^{trans}$, $v_e$ e $v_p$.
- A técnica de ASL oferece uma alternativa não invasiva, sem contraste exógeno, com potencial para detectar alterações de permeabilidade e perfusão em cenários clínicos relevantes.
- A proposta do estudo é testar se a permeabilidade estimada por ASL apresenta concordância com o padrão de referência em indivíduos com EM, especialmente nas lesões e em regiões mais vulneráveis à inflamação.

---

## Hipóteses do estudo

### Hipótese primária

- A métrica de permeabilidade da BHE derivada de ASL correlaciona-se significativamente e positivamente com a taxa de transferência endotelial ($K^{trans}$) estimada por DCE-MRI.

### Hipóteses secundárias

- A correlação entre ASL e DCE é mais forte em lesões do que em tecido aparentemente normal.
- A associação é mais acentuada em lesões com realce ou atividade inflamatória do que em lesões sem realce.
- O ASL pode capturar alterações sutis de permeabilidade em NAWM/perilesão, complementando a avaliação por contraste.
- O comportamento dos mapas quantitativos pode diferir entre substância branca e substância cinzenta, refletindo heterogeneidade regional de BHE.

---

## Perguntas centrais a responder

- O ASL detecta a mesma assinatura espacial de permeabilidade da BHE observada por DCE-MRI?
- A concordância é maior em lesões do que em tecido normal?
- A correlação entre ASL e DCE é robusta em análise voxel a voxel?
- O ASL consegue diferenciar lesões ativas de lesões menos inflamatórias?
- A análise por ROI permite uma leitura clínica clara e quantitativa dos resultados?

---

## Desenho analítico proposto

### 1) Análise voxel a voxel

- Correlação espacial voxel a voxel entre mapas de ASL e DCE-MRI.
- Uso de Pearson e/ou Spearman para avaliar concordância contínua.
- Regressão linear voxelwise para avaliar associação entre valores quantitativos.
- Mapa de correlação espacial médio no espaço padrão.
- Avaliação de viés regional por tecido (substância branca vs substância cinzenta).

Checklist:

- [ ] Garantir alinhamento espacial rígido/afim entre ASL, DCE, T1 e FLAIR.
- [ ] Verificar qualidade dos mapas quantitativos antes da correlação.
- [ ] Definir máscara de cérebro completo adequada para análise voxelwise.
- [ ] Validar outliers e artefatos em regiões de movimento/voxel sem sinal.

### 2) Análise por região de interesse (ROI)

- Lesão total.
- Lesões com realce (GdT1+).
- Lesões sem realce (GdT1-).
- NAWM (substância branca aparentemente normal).
- NAGM / GM (substância cinzenta cortical e profunda).
- Região perilesional, quando aplicável.

Métricas esperadas:

- [ ] Média e mediana dos mapas por compartimento.
- [ ] Scatter plots entre ASL e DCE por ROI.
- [ ] Coeficiente de correlação intraclasse (ICC), quando apropriado.
- [ ] $R^2$ e regressão linear por região.
- [ ] Bland-Altman para avaliação de concordância e viés entre escalas.

### 3) Análise topológica / espacial de overlap

- Binarização de regiões de hiperpermeabilidade para comparação entre ASL e DCE.
- Cálculo de Dice, Jaccard e overlap percentual.
- Comparação entre perfis de lesões ativas x não ativas.

Checklist:

- [ ] Definir limiares de hiperpermeabilidade em cada método.
- [ ] Validar sensibilidade dos limiares para cada compartimento.
- [ ] Comparar cobertura espacial entre mapas binários.

---

## Dados e pré-requisitos metodológicos

### Dados esperados

- ASL processado em pipeline já utilizado no estudo anterior.
- DCE-MRI com mapas derivados de modelagem farmacocinética (ex.: $K^{trans}$, $v_e$, $v_p$).
- Imagens anatômicas: T1, FLAIR.
- Lesões segmentadas por LST-AI ou outra ferramenta validada.
- Dados clínicos relevantes: diagnóstico, tipo de doença, atividade inflamatória, status de tratamento, etc.

### Fluxo metodológico esperado

- Aquisição/organização dos dados em uma estrutura consistente.
- Homogeneização do espaço de imagem.
- Registro espacial entre ASL, DCE e anatomia.
- Segmentação de lesões e definição dos compartimentos.
- Extração de métricas quantitativas por voxel e por ROI.
- Análise estatística e geração de figuras para abstract.

---

## Checklist operacional do estudo

### Etapa 1 - Organização dos dados

- [ ] Baixar e organizar os dados de DCE no repositório/estrutura de trabalho.
- [ ] Confirmar que os exames têm as sequências necessárias para processamento.
- [ ] Validar a presença de T1, FLAIR, ASL e DCE para cada paciente.
- [ ] Checar a qualidade das imagens e presença de artefatos.

### Etapa 2 - Registro espacial e segmentação

- [ ] Definir espaço comum para análise (T1 nativo ou MNI152, conforme melhor ajuste do pipeline).
- [ ] Realizar registro de ASL, DCE, T1 e FLAIR no mesmo espaço.
- [ ] Rodar LST-AI para segmentação de lesões.
- [ ] Definir máscaras de lesão, NAWM, GM e perilesão.
- [ ] Validar a segmentação visualmente para cada caso.

### Etapa 3 - Processamento quantitativo

- [ ] Processar DCE-MRI com PKmodeling para extrair mapas de permeabilidade.
- [ ] Extrair mapas quantitativos de ASL no mesmo espaço de referência.
- [ ] Garantir que os mapas possam ser comparados em mesma geometria e resolução.
- [ ] Normalizar ou padronizar escalas quando necessário para comparação.

### Etapa 4 - Análise estatística

- [ ] Executar correlação voxel a voxel entre ASL e DCE.
- [ ] Executar comparação por ROI para lesões e tecido normal.
- [ ] Avaliar efeito de lesão ativa vs não ativa.
- [ ] Considerar análise exploratória de NAWM e perilesão.
- [ ] Produzir gráficos de scatter, correlação e Bland-Altman.

### Etapa 5 - Artefatos, QC e robustez

- [ ] Validar qualidade dos mapas e alinhamento de voxels.
- [ ] Revisar pacientes com movimento ou baixa qualidade de aquisição.
- [ ] Analisar sensibilidade dos resultados a limiares e máscaras.
- [ ] Registrar decisões analíticas para reprodutibilidade.

### Etapa 6 - Entrega para abstract e paper

- [ ] Definir amostra final e critérios de inclusão/exclusão.
- [ ] Montar figura principal do abstract.
- [ ] Revisar resultados com foco em clareza e impacto metodológico.
- [ ] Redigir texto do abstract em formato ISMRM.
- [ ] Preparar versão inicial para discussão com a equipe.

---

## Cronograma recomendado

### Semana 1 (até 07/10)

- [ ] Organização dos dados do DCE e revisão das imagens.
- [ ] Verificação do pipeline ASL já processado.
- [ ] Definição da cadeia de transformações espaciais.
- [ ] Execução do LST-AI em lote para segmentação de lesões.

### Semana 2 (até 14/10)

- [ ] Processamento do DCE no 3D Slicer / PKmodeling.
- [ ] Extração dos mapas quantitativos relevantes.
- [ ] Alinhamento e validação final dos mapas em espaço comum.

### Semana 3 (até 21/10)

- [ ] Análise voxelwise e por ROI.
- [ ] Geração de gráficos principais e avaliação estatística.
- [ ] Revisão de qualidade, artefatos e robustez.

### Semana 4 (até 28/10)

- [ ] Seleção dos principais resultados para abstract.
- [ ] Elaboração do texto do abstract.
- [ ] Revisão final da figura central.
- [ ] Entrega do abstract ISMRM.

---

## Entregáveis esperados

- Base de dados organizada e validada.
- Pipeline de registro e segmentação documentado.
- Mapas quantitativos de ASL e DCE compatíveis espacialmente.
- Resultados em análise voxelwise e por ROI.
- Figura principal para abstract.
- Texto do abstract em formato ISMRM.
- Estrutura preparada para expandir o estudo em paper futuro com NMO e MOGAD.

---

## Observações estratégicas

- O prazo de 28 de outubro exige foco no desenho analítico e no delivery do abstract, sem dispersão em refinamentos excessivos de pipeline.
- A prioridade é validar a hipótese central: ASL como alternativa não invasiva para estimar permeabilidade da BHE em comparação com DCE-MRI.
- A análise por lesão deve ser priorizada, mas a combinação entre total-brain e ROI será crucial para demonstrar robustez e relevância clínica.
- A separação entre segmentos de lesão e tecido aparentemente normal deve estar clara na apresentação dos resultados.

---

## Próximo passo recomendado

1. Confirmar a estrutura de dados e o acesso ao Drive com os exames de DCE.
2. Validar a pipeline de registro espacial e segmentação.
3. Definir a primeira versão dos mapas e das ROIs a serem analisadas.
4. Transformar este README em checklist operacional com subtarefas por script/pipeline.

Este arquivo deve servir como base de planejamento, alinhar hipóteses, critérios analíticos e entregáveis antes da implementação específica dos scripts e processamento de dados.
