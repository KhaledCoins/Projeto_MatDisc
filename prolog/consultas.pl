% gerado por etl/gerar_base.py
% rodar com: swipl prolog/consultas.pl
% no SWISH, usar as consultas marcadas com ?- abaixo

:- consult(base_conhecimento).
:- consult(regras).
:- discontiguous pergunta/2, resposta/2.
:- initialization(main, main).

% Quanto um segurado fumante custa a mais, em media, do que um nao fumante? (diferenca absoluta e razao)
% ?- premio_fumante(MediaFumante, MediaNaoFumante, Diferenca, Razao).
pergunta(1, "Quanto um segurado fumante custa a mais, em media, do que um nao fumante? (diferenca absoluta e razao)").
resposta(1, [media_fumante=MediaFumante, media_nao_fumante=MediaNaoFumante, diferenca=Diferenca, razao=Razao]) :-
    premio_fumante(MediaFumante, MediaNaoFumante, Diferenca, Razao).

% Qual o ranking das regioes por custo medio, e a taxa de fumantes em cada uma explica a posicao no ranking?
% ?- ranking_regioes(Ranking), regiao_mais_cara(Regiao, Media), findall(R-T, taxa_fumantes_regiao(R, T), Taxas).
pergunta(2, "Qual o ranking das regioes por custo medio, e a taxa de fumantes em cada uma explica a posicao no ranking?").
resposta(2, [ranking_custo_medio=Ranking, regiao_mais_cara=Regiao, custo_medio=Media, taxa_fumantes_pct=Taxas]) :-
    ranking_regioes(Ranking), regiao_mais_cara(Regiao, Media), findall(R-T, taxa_fumantes_regiao(R, T), Taxas).

% Combinando faixa etaria, faixa de IMC e tabagismo, qual perfil de segurado e o mais caro e qual e o mais barato para o plano?
% ?- perfil_mais_caro(PerfilCaro, MediaCara, NCaro), perfil_mais_barato(PerfilBarato, MediaBarata, NBarato).
pergunta(3, "Combinando faixa etaria, faixa de IMC e tabagismo, qual perfil de segurado e o mais caro e qual e o mais barato para o plano?").
resposta(3, [perfil_mais_caro=PerfilCaro, media=MediaCara, segurados=NCaro, perfil_mais_barato=PerfilBarato, media_barata=MediaBarata, segurados_barato=NBarato]) :-
    perfil_mais_caro(PerfilCaro, MediaCara, NCaro), perfil_mais_barato(PerfilBarato, MediaBarata, NBarato).

% Quantos segurados tem custo atipico (mais que o dobro da media da propria regiao), como eles se distribuem por regiao e que percentual deles e fumante?
% ?- total_atipicos(Total), findall(R-(Q, P), qtd_atipicos_regiao(R, Q, P), PorRegiao), fumantes_entre_atipicos(PctFumantes).
pergunta(4, "Quantos segurados tem custo atipico (mais que o dobro da media da propria regiao), como eles se distribuem por regiao e que percentual deles e fumante?").
resposta(4, [total_atipicos=Total, por_regiao_qtd_pct=PorRegiao, pct_fumantes_entre_atipicos=PctFumantes]) :-
    total_atipicos(Total), findall(R-(Q, P), qtd_atipicos_regiao(R, Q, P), PorRegiao), fumantes_entre_atipicos(PctFumantes).

% Quais sao os 5 segurados mais caros do plano e qual o perfil (faixa etaria, IMC, tabagismo) de cada um?
% ?- top_n_custos(5, Top).
pergunta(5, "Quais sao os 5 segurados mais caros do plano e qual o perfil (faixa etaria, IMC, tabagismo) de cada um?").
resposta(5, Top) :-
    top_n_custos(5, Top).

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
