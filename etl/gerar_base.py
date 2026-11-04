"""
Lê o insurance.csv e gera os arquivos Prolog do projeto:

    prolog/base_conhecimento.pl   fatos segurado/8
    prolog/consultas.pl           as perguntas, com um main que imprime as respostas
    prolog/programa_swish.pl      base + regras num arquivo só, para colar no SWISH

Uso: python etl/gerar_base.py [--csv caminho.csv] [--saida pasta]
"""

import argparse
import csv
from pathlib import Path

SEXO = {"male": "masculino", "female": "feminino"}
FUMANTE = {"yes": "sim", "no": "nao"}
REGIAO = {
    "southeast": "sudeste",
    "southwest": "sudoeste",
    "northeast": "nordeste",
    "northwest": "noroeste",
}

PERGUNTAS = [
    {
        "texto": "Quanto um segurado fumante custa a mais, em media, do que um "
                 "nao fumante? (diferenca absoluta e razao)",
        "consulta": "premio_fumante(MediaFumante, MediaNaoFumante, Diferenca, Razao)",
        "resultado": "[media_fumante=MediaFumante, media_nao_fumante=MediaNaoFumante, "
                     "diferenca=Diferenca, razao=Razao]",
    },
    {
        "texto": "Qual o ranking das regioes por custo medio, e a taxa de "
                 "fumantes em cada uma explica a posicao no ranking?",
        "consulta": "ranking_regioes(Ranking), regiao_mais_cara(Regiao, Media), "
                    "findall(R-T, taxa_fumantes_regiao(R, T), Taxas)",
        "resultado": "[ranking_custo_medio=Ranking, regiao_mais_cara=Regiao, "
                     "custo_medio=Media, taxa_fumantes_pct=Taxas]",
    },
    {
        "texto": "Combinando faixa etaria, faixa de IMC e tabagismo, qual perfil "
                 "de segurado e o mais caro e qual e o mais barato para o plano?",
        "consulta": "perfil_mais_caro(PerfilCaro, MediaCara, NCaro), "
                    "perfil_mais_barato(PerfilBarato, MediaBarata, NBarato)",
        "resultado": "[perfil_mais_caro=PerfilCaro, media=MediaCara, segurados=NCaro, "
                     "perfil_mais_barato=PerfilBarato, media_barata=MediaBarata, "
                     "segurados_barato=NBarato]",
    },
    {
        "texto": "Quantos segurados tem custo atipico (mais que o dobro da media "
                 "da propria regiao), como eles se distribuem por regiao e que "
                 "percentual deles e fumante?",
        "consulta": "total_atipicos(Total), "
                    "findall(R-(Q, P), qtd_atipicos_regiao(R, Q, P), PorRegiao), "
                    "fumantes_entre_atipicos(PctFumantes)",
        "resultado": "[total_atipicos=Total, por_regiao_qtd_pct=PorRegiao, "
                     "pct_fumantes_entre_atipicos=PctFumantes]",
    },
    {
        "texto": "Quais sao os 5 segurados mais caros do plano e qual o perfil "
                 "(faixa etaria, IMC, tabagismo) de cada um?",
        "consulta": "top_n_custos(5, Top)",
        "resultado": "Top",
    },
]

CABECALHO_BASE = """\
% gerado por etl/gerar_base.py a partir de data/raw/insurance.csv
% segurado(Id, Idade, Sexo, Imc, Filhos, Fumante, Regiao, Custo).

"""

CABECALHO_CONSULTAS = """\
% gerado por etl/gerar_base.py
% rodar com: swipl prolog/consultas.pl
% no SWISH, usar as consultas marcadas com ?- abaixo

:- consult(base_conhecimento).
:- consult(regras).
:- discontiguous pergunta/2, resposta/2.
:- initialization(main, main).

"""

RODAPE_CONSULTAS = """\
main :-
    forall(pergunta(N, Texto),
           ( format("~n=== Pergunta ~w ===~n~w~n", [N, Texto]),
             (   resposta(N, Resultado)
             ->  mostrar(Resultado)
             ;   format("  (sem resposta)~n")
             ) )).

mostrar(Lista) :-
    is_list(Lista), !,
    forall(member(Item, Lista), mostrar_item(Item)).
mostrar(Valor) :-
    mostrar_item(Valor).

mostrar_item(Chave=Valor) :- !,
    format("  ~w = ", [Chave]), mostrar_valor(Valor), nl.
mostrar_item(Valor) :-
    format("  "), mostrar_valor(Valor), nl.

mostrar_valor(V) :- float(V), !, format("~2f", [V]).
mostrar_valor(V) :- is_list(V), !,
    nl, forall(member(E, V), (format("      "), mostrar_valor(E), nl)).
mostrar_valor(A-B) :- !, mostrar_valor(A), format(" - "), mostrar_valor(B).
mostrar_valor((A, B)) :- !, mostrar_valor(A), format(", "), mostrar_valor(B).
mostrar_valor(V) :- format("~w", [V]).
"""


def numero(texto):
    valor = float(texto)
    if valor.is_integer():
        return str(int(valor))
    return repr(round(valor, 3))


def fato(idx, linha):
    return "segurado({}, {}, {}, {}, {}, {}, {}, {:.2f}).".format(
        idx,
        int(linha["age"]),
        SEXO[linha["sex"].strip().lower()],
        numero(linha["bmi"]),
        int(linha["children"]),
        FUMANTE[linha["smoker"].strip().lower()],
        REGIAO[linha["region"].strip().lower()],
        float(linha["charges"]),
    )


def gerar_base(csv_path, saida):
    with csv_path.open(newline="", encoding="utf-8") as f:
        linhas = list(csv.DictReader(f))
    fatos = [fato(i, linha) for i, linha in enumerate(linhas, start=1)]
    (saida / "base_conhecimento.pl").write_text(
        CABECALHO_BASE + "\n".join(fatos) + "\n", encoding="utf-8")
    return len(fatos)


def gerar_consultas(saida):
    blocos = []
    for n, p in enumerate(PERGUNTAS, start=1):
        blocos.append(
            f"% {p['texto']}\n"
            f"% ?- {p['consulta']}.\n"
            f"pergunta({n}, \"{p['texto']}\").\n"
            f"resposta({n}, {p['resultado']}) :-\n"
            f"    {p['consulta']}.\n"
        )
    (saida / "consultas.pl").write_text(
        CABECALHO_CONSULTAS + "\n".join(blocos) + "\n" + RODAPE_CONSULTAS, encoding="utf-8")
    return len(PERGUNTAS)


def gerar_programa_swish(saida):
    base = (saida / "base_conhecimento.pl").read_text(encoding="utf-8")
    regras = (saida / "regras.pl").read_text(encoding="utf-8")
    (saida / "programa_swish.pl").write_text(
        "% gerado por etl/gerar_base.py: base + regras para colar no SWISH\n\n"
        + base + "\n" + regras, encoding="utf-8")


def main():
    raiz = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=raiz / "data" / "raw" / "insurance.csv")
    parser.add_argument("--saida", type=Path, default=raiz / "prolog")
    args = parser.parse_args()

    args.saida.mkdir(parents=True, exist_ok=True)
    n_fatos = gerar_base(args.csv, args.saida)
    n_perguntas = gerar_consultas(args.saida)
    gerar_programa_swish(args.saida)
    print(f"{n_fatos} fatos e {n_perguntas} perguntas gravados em {args.saida}")


if __name__ == "__main__":
    main()
