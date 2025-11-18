# Sistema Inteligente de Monitoramento e Controle de Pragas em Sorgo

## 1. Visão Geral

Este projeto é uma plataforma de simulação para um sistema automatizado de manejo de pragas na cultura do sorgo. O objetivo é otimizar a tomada de decisão, reduzir custos com defensivos e aumentar a sustentabilidade da lavoura através do uso de tecnologia de ponta.

A plataforma simula um fluxo de trabalho completo, desde a coleta de dados por drones até a execução de ações específicas em campo por uma equipe de solo (trabalhador e trator), tudo orquestrado por um sistema especialista com regras de negócio pré-definidas.

---

## 2. O Fluxo de Trabalho Automatizado

O sistema opera em ciclos contínuos e lógicos, divididos em duas fases principais:

### Fase 1: Turno de Coleta (Drone)
1.  **Varredura Completa:** O drone decola de forma autônoma da base da fazenda.
2.  **Inspeção em Campo:** Ele visita **todos os 4 talhões** da propriedade, um por um. Em cada talhão, ele realiza uma varredura (simulada pelo movimento em zig-zag) para coletar imagens e dados sobre a saúde da plantação.
3.  **Retorno e Entrega de Dados:** Após inspecionar todos os talhões, o drone retorna à base para "descarregar" os dados coletados para análise do sistema.

### Fase 2: Turno de Ação (Trabalhador e Trator)
1.  **Análise e Decisão:** O sistema especialista analisa os dados recebidos do drone. Para cada talhão, ele identifica a praga, determina a severidade da infestação e consulta a Matriz de Decisão para definir o plano de ação mais eficiente.
2.  **Despacho da Equipe:** Com base no plano, as ordens de serviço são geradas. O trabalhador (para ações manuais/físicas) e/o trator (para ações de aplicação biológica/química) são enviados **apenas aos talhões que necessitam de intervenção**.
3.  **Execução Coordenada:** A equipe de solo executa as tarefas designadas em cada talhão problemático.
4.  **Retorno à Base:** Ao final de todas as ações, a equipe retorna à base, concluindo o ciclo.

O processo todo se repete, garantindo um monitoramento constante e ações precisas.

---

## 3. A Matriz de Decisão Inteligente

Este é o "cérebro" do sistema. As decisões de controle são tomadas com base nas seguintes regras, que visam o Manejo Integrado de Pragas (MIP), priorizando métodos menos agressivos.

| Praga Detectada | Nível de Infestação | Ação Recomendada | Agente / Método | Executor | Eficácia Estimada |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Lagarta-do-cartucho** | Leve (< 30%) | Controle Biológico | `Trichogramma` | Trator | 45% |
| | Moderada (30-70%) | Controle Microbiológico | `Bacillus thuringiensis` | Trator | 28% |
| | Alta (> 70%) | Controle Integrado | `Trichogramma + B. thuringiensis` | Trator | 73% |
| **Pulgão-verde** | Leve a Alta | Controle Biológico | `Joaninhas` | Trator | 45-50% |
| **Mosca-do-sorgo** | Leve (< 30%) | Controle Físico-Mecânico | `Armadilhas com feromônio` | Trabalhador | 18% |
| | Moderada (30-70%) | Controle Biológico | `Parasitoides` | Trator | 45% |
| | Alta (> 70%) | Controle Integrado | `Parasitoides + Armadilhas` | Ambos | 63% |
| **Percevejos-da-panícula**| Leve a Alta | Controle Biológico | `Parasitoides de ovos` | Trator | 45-50% |
| **Broca-da-cana** | Leve (< 30%) | Controle Microbiológico | `Baculovírus` | Trator | 28% |
| | Moderada (30-70%) | Controle Microbiológico | `Baculovírus (reforçado)` | Trator | 30% |
| | Alta (> 70%) | Controle Integrado | `Baculovírus + Trichogramma` | Trator | 70% |
| **Larva-arame / Corós** | Leve a Alta | Controle Cultural | `Rotação de culturas` | Trabalhador | 18% |

---

## 4. Benefícios do Sistema

*   **Otimização de Recursos:** Aplica insumos apenas nas áreas necessárias, reduzindo custos e desperdício.
*   **Sustentabilidade:** Prioriza controles biológicos e microbiológicos, diminuindo o impacto ambiental.
*   **Tomada de Decisão Ágil:** Automatiza o ciclo de detecção-decisão-ação, permitindo respostas rápidas a infestações.
*   **Rastreabilidade e Análise:** Gera um histórico completo de todas as operações, permitindo análises de tendências e identificação de talhões problemáticos através do dashboard.
*   **Redução de Risco:** O monitoramento constante ajuda a prevenir que infestações leves se tornem severas, protegendo a produtividade da lavoura.
