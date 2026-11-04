# Knowledge Engine: custos de plano de saúde em Prolog

Projeto da disciplina de Lógica e Matemática Discreta (Insper, 2026/1).

A proposta é montar uma base de conhecimento em Prolog a partir de um dataset público e
responder perguntas sobre ele usando só lógica de primeira ordem, na linha dos sistemas de
IA antigos que respondiam por inferência em cima de uma base de fatos. O ETL que transforma
o dataset em fatos Prolog é feito em Python; todo o resto (regras e consultas) é Prolog.

Autor: Eduardo Khaled

## Por que esse dataset

Eu trabalho com corretagem de seguros, então fui atrás de alguma coisa dessa área que
coubesse nas regras do projeto: uma tabela só, de 6 a 10 campos, misturando variáveis
qualitativas e quantitativas. Acabei escolhendo o *Medical Cost Personal Dataset*
(https://www.kaggle.com/datasets/mirichoi0218/insurance). São 1.338 beneficiários de um
plano de saúde americano, com alguns dados demográficos e o custo médico anual que cada um
gerou para o plano.

Gostei dele porque é pequeno o bastante para a base Prolog continuar legível, não tem valor
faltando e a pergunta por trás dos dados é a mesma que uma seguradora faz na hora de
precificar: o que faz um segurado sair mais caro?

A tabela tem exatamente 7 campos e usei todos:

| campo no CSV | tipo         | nome na base | valores                                        |
|--------------|--------------|--------------|------------------------------------------------|
| `age`        | quantitativa | `Idade`      | 18 a 64 anos                                   |
| `sex`        | qualitativa  | `Sexo`       | `masculino`, `feminino`                        |
| `bmi`        | quantitativa | `Imc`        | 15,96 a 53,13                                  |
| `children`   | quantitativa | `Filhos`     | 0 a 5 dependentes                              |
| `smoker`     | qualitativa  | `Fumante`    | `sim`, `nao`                                   |
| `region`     | qualitativa  | `Regiao`     | `nordeste`, `noroeste`, `sudeste`, `sudoeste`  |
| `charges`    | quantitativa | `Custo`      | de US$ 1.121,87 a US$ 63.770,43 por ano        |

Como a tabela original não tem chave primária, o ETL acrescenta um `Id` sequencial (1 a
1338). Sem isso não dá para responder perguntas do tipo "quais são os cinco segurados mais
caros", porque dois segurados com os mesmos valores seriam indistinguíveis.

Deixei uma cópia do CSV em `data/raw/insurance.csv`, então o projeto roda sem precisar de
conta no Kaggle.

## Organização do repositório

```
data/raw/insurance.csv       dataset original, do jeito que veio
etl/gerar_base.py            ETL em Python: lê o CSV e escreve os arquivos .pl
prolog/regras.pl             as regras, escritas à mão
prolog/base_conhecimento.pl  gerado pelo ETL: 1338 fatos segurado/8
prolog/consultas.pl          gerado pelo ETL: as 5 perguntas e um main que imprime as respostas
prolog/programa_swish.pl     gerado pelo ETL: base + regras num arquivo só, para colar no SWISH
```

## Como a base foi construída

### Explorando os dados

Antes de escrever qualquer coisa eu abri o CSV em Python para ver os domínios: quais valores
aparecem em `sex`, `smoker` e `region`, e os mínimos e máximos de `age`, `bmi` e `charges`.
Foi isso que definiu a tradução dos átomos e as faixas que uso nas regras de classificação
mais para frente. Também confirmei que não havia linha vazia nem valor estranho.

### O ETL

O script `etl/gerar_base.py` só usa a biblioteca padrão do Python (módulo `csv`). Ele lê o
arquivo linha a linha e transforma cada uma em um fato de aridade 8:

```prolog
% segurado(Id, Idade, Sexo, Imc, Filhos, Fumante, Regiao, Custo).
segurado(1, 19, feminino, 27.9, 0, sim, sudoeste, 16884.92).
segurado(2, 18, masculino, 33.77, 1, nao, sudeste, 1725.55).
segurado(3, 28, masculino, 33, 3, nao, sudeste, 4449.46).
```

Algumas decisões que tomei nessa etapa:

- Os valores qualitativos viraram átomos em português e em minúsculo (`male` virou
  `masculino`, `yes` virou `sim`, `southeast` virou `sudeste`). Evitei acento de propósito,
  seguindo a dica do enunciado e porque o terminal do Windows às vezes embaralha UTF-8.
- `age` e `children` ficaram inteiros, `bmi` ficou com no máximo três casas e `charges` foi
  arredondado para duas casas. Isso quer dizer que as médias calculadas em Prolog podem
  diferir das médias sobre o CSV cru em menos de um centavo, o que achei aceitável.
- O ponto final de cada fato é escrito pelo script, para não correr o risco de esquecer.

O enunciado pede que o script em Python gere também as perguntas em formato Prolog. Resolvi
isso declarando as perguntas numa lista no próprio script, cada uma com o texto em
português e a consulta Prolog correspondente. A partir dessa lista o ETL escreve o
`prolog/consultas.pl`, que para cada pergunta traz a consulta pronta para colar no SWISH
(numa linha de comentário começando com `?-`) e um par `pergunta/2` e `resposta/2` que o
predicado `main/0` percorre e imprime. Assim a pergunta e a consulta ficam num lugar só e eu
não tenho como deixar as duas dessincronizadas.

Por último o script cola `base_conhecimento.pl` e `regras.pl` num arquivo único,
`programa_swish.pl`, porque no SWISH é mais fácil colar um arquivo só na área Program.

### As regras

As regras estão em `prolog/regras.pl` e tentei organizar em camadas, da mais básica para a
mais composta.

Na base de tudo ficam predicados de acesso (`custo/2`, `regiao_de/2`, `fumante/1`) e dois
auxiliares numéricos, `media/2` e `percentual/3`. A `media/2` é a do tutorial: `sum_list`
dividido por `length`. As regiões não estão escritas em lista fixa; `regiao/1` descobre
quais existem com um `setof` sobre a própria base, então se o CSV mudar as regras continuam
valendo.

Para as perguntas de agrupamento eu segui o padrão que o próprio enunciado ensina para não
cair no erro do `findall` com variável livre: um predicado "gerador" fixa a chave do grupo
(a região, o perfil, se é fumante ou não) e só então o `findall` coleta os custos daquele
grupo. Fica assim para região:

```prolog
custo_medio_regiao(Regiao, Media, N) :-
    regiao(Regiao),
    findall(C, segurado(_, _, _, _, _, _, Regiao, C), Custos),
    length(Custos, N),
    media(Custos, Media).
```

Para ordenar, uso `setof(Chave-Valor, ...)`, que já devolve ordenado de forma crescente e
sem repetição, seguido de `reverse/2` quando quero o maior primeiro. Foi a mesma ideia da
tabela do Brasileirão do tutorial.

A parte que mais gostei de fazer foi a de perfis. Duas regras pequenas classificam cada
segurado: `faixa_imc/2` usa os cortes da OMS (abaixo do peso, normal, sobrepeso, obesidade)
e `faixa_etaria/2` divide em jovem (até 29), adulto (30 a 49) e senior (50 ou mais).
Combinando as duas com a coluna de tabagismo nasce o termo
`perfil(FaixaEtaria, FaixaImc, Fumante)`, e a partir daí dá para calcular média por perfil,
ordenar perfis e procurar o mais caro e o mais barato. Coloquei um tamanho mínimo de 10
segurados por grupo (`tamanho_minimo_grupo/1`), senão um perfil com dois ou três casos
distorce o ranking.

## As perguntas

Procurei fugir de perguntas que fossem só filtro: todas envolvem agregação, ordenação,
comparação ou composição de regras. Os valores abaixo são a saída de
`swipl prolog/consultas.pl`. Para não confiar cegamente no que eu mesmo escrevi, refiz as
cinco contas em Python puro, em cima do CSV, e os números bateram.

### 1. Quanto um fumante custa a mais, em média, do que um não fumante?

```prolog
?- premio_fumante(MediaFumante, MediaNaoFumante, Diferenca, Razao).
```

```
media_fumante      = 32050.23
media_nao_fumante  =  8434.27
diferenca          = 23615.96
razao              =     3.80
```

A regra calcula a média de cada grupo separadamente e depois faz a diferença e a razão
entre as duas. O resultado é bem mais forte do que eu esperava: um fumante custa quase
quatro vezes um não fumante. Nenhum outro corte que fiz na base chega perto disso.

### 2. Qual é o ranking das regiões por custo médio, e a taxa de fumantes explica a posição?

```prolog
?- ranking_regioes(Ranking), regiao_mais_cara(Regiao, Media),
   findall(R-T, taxa_fumantes_regiao(R, T), Taxas).
```

| posição | região   | custo médio   | fumantes |
|---------|----------|---------------|----------|
| 1       | sudeste  | US$ 14.735,41 | 25,00 %  |
| 2       | nordeste | US$ 13.406,38 | 20,68 %  |
| 3       | noroeste | US$ 12.417,58 | 17,85 %  |
| 4       | sudoeste | US$ 12.346,94 | 17,85 %  |

Aqui tem dois agregados compostos: o ranking de custo e, por cima dele, a taxa de fumantes
de cada região. A ordem é a mesma nas duas colunas. O sudeste é a região mais cara e é
também a que tem mais fumantes, o que conversa com a pergunta anterior.

### 3. Combinando faixa etária, IMC e tabagismo, qual perfil é o mais caro e qual é o mais barato?

```prolog
?- perfil_mais_caro(PerfilCaro, MediaCara, NCaro),
   perfil_mais_barato(PerfilBarato, MediaBarata, NBarato).
```

```
perfil_mais_caro    = perfil(senior, obesidade, sim)   media = 46973.11   (41 segurados)
perfil_mais_barato  = perfil(jovem, obesidade, nao)    media =  4423.03   (160 segurados)
```

Essa é a pergunta que mais encadeia regras: classificação de IMC, classificação de idade,
montagem do perfil, média por perfil com corte de tamanho mínimo, ordenação e extração dos
extremos. O detalhe que achei interessante é que a obesidade aparece nos dois extremos.
Sozinha, em gente jovem que não fuma, ela pesa pouco; junto com tabagismo e idade avançada
o custo médio fica mais de dez vezes maior.

### 4. Quantos segurados têm custo atípico, como se distribuem por região e quantos deles fumam?

Defini como atípico quem custa mais que o dobro da média da própria região. Comparar cada
pessoa com o agregado do seu grupo, e não com a média geral, evita que uma região mais cara
inflacione a contagem das outras.

```prolog
?- total_atipicos(Total),
   findall(R-(Q, P), qtd_atipicos_regiao(R, Q, P), PorRegiao),
   fumantes_entre_atipicos(PctFumantes).
```

```
total_atipicos = 185

  nordeste   40 atipicos   12.35 % da regiao
  noroeste   42 atipicos   12.92 % da regiao
  sudeste    61 atipicos   16.76 % da regiao
  sudoeste   42 atipicos   12.92 % da regiao

pct_fumantes_entre_atipicos = 88.65
```

São 185 segurados atípicos, cerca de 14 % da base. O número que mais chama atenção é o
último: quase 89 % deles fumam, sendo que fumantes são só 20 % da base. Em outras palavras,
quando o custo foge da curva, quase sempre tem cigarro no meio.

### 5. Quais são os cinco segurados mais caros e qual é o perfil de cada um?

```prolog
?- top_n_custos(5, Top).
```

| id   | custo anual   | perfil                           |
|------|---------------|----------------------------------|
| 544  | US$ 63.770,43 | `perfil(senior, obesidade, sim)` |
| 1301 | US$ 62.592,87 | `perfil(adulto, obesidade, sim)` |
| 1231 | US$ 60.021,40 | `perfil(senior, obesidade, sim)` |
| 578  | US$ 58.571,07 | `perfil(adulto, obesidade, sim)` |
| 820  | US$ 55.135,40 | `perfil(adulto, obesidade, sim)` |

A regra ordena a base inteira por custo com `setof`, inverte, corta os N primeiros com
`length` e `append`, e para cada um busca o perfil. Os cinco são obesos e fumantes, sem
exceção, o que fecha com o que a pergunta 3 já tinha mostrado.

## Como rodar

Precisa de Python 3.8 ou mais novo (sem instalar nada além dele) e do SWI-Prolog. Eu usei
a versão 10.0.2 do SWI-Prolog no Windows. Se não quiser instalar nada, dá para usar o SWISH
online, explico logo abaixo.

### No terminal

Regerar a base e as consultas a partir do CSV (opcional, os arquivos gerados já estão no
repositório):

```bash
python etl/gerar_base.py
```

Rodar as cinco perguntas e ver as respostas:

```bash
swipl prolog/consultas.pl
```

No Windows, se o `swipl` não estiver no PATH, o caminho padrão é
`C:\Program Files\swipl\bin\swipl.exe`.

Para brincar com a base de forma interativa:

```bash
swipl prolog/programa_swish.pl
```

```prolog
?- custo_medio_regiao(sudeste, Media, N).
?- ranking_perfis(Ranking).
?- custo_atipico(Id, Custo, nordeste, MediaRegiao).
```

### No SWISH (https://swish.swi-prolog.org/)

1. Crie um programa novo.
2. Cole o conteúdo de `prolog/programa_swish.pl` na área Program. Ele já traz os 1.338
   fatos e todas as regras.
3. Na área Query, digite qualquer uma das consultas da seção anterior. Elas também estão
   nas linhas que começam com `?-` dentro de `prolog/consultas.pl`.

O `consultas.pl` em si não serve para o SWISH, porque usa `consult/1` com caminho relativo
e `initialization/2` para rodar como script no terminal.

### Usando outro CSV

O ETL aceita outro caminho de entrada e de saída:

```bash
python etl/gerar_base.py --csv outro/arquivo.csv --saida prolog
```

## O que me deu trabalho

- `findall` com variável livre. Na primeira versão de `custo_medio_regiao` eu esqueci de
  fixar a região antes do `findall` e a média saía igual para todas (era a média geral).
  O tutorial avisa exatamente disso e mesmo assim caí.
- O operador `^` dentro do `setof`. Sem ele o `setof` agrupa pelas variáveis que sobram
  livres e devolve vários conjuntos em vez de um. Precisei dele em `regioes/1` e `perfis/1`.
- Caminho relativo no `consult/1`. Funciona porque o SWI-Prolog resolve o caminho em relação
  ao arquivo que está sendo carregado, não ao diretório de onde o comando foi chamado.
- Formatação da saída. Para o relatório do terminal ficar legível escrevi um `mostrar/1`
  pequeno que imprime float com duas casas, listas uma por linha e pares `A-B` separados por
  hífen. É só apresentação, nenhuma pergunta depende dele.

## Fontes

- Dataset: Miri Choi, *Medical Cost Personal Datasets*, Kaggle
  (https://www.kaggle.com/datasets/mirichoi0218/insurance). Os dados vêm originalmente do
  livro *Machine Learning with R*, de Brett Lantz.
- Cortes de IMC: classificação da Organização Mundial da Saúde.
- SWI-Prolog e SWISH: https://www.swi-prolog.org/
