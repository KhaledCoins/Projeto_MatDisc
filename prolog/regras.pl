% segurado(Id, Idade, Sexo, Imc, Filhos, Fumante, Regiao, Custo).

custo(Id, Custo) :- segurado(Id, _, _, _, _, _, _, Custo).
regiao_de(Id, Regiao) :- segurado(Id, _, _, _, _, _, Regiao, _).
fumante(Id) :- segurado(Id, _, _, _, _, sim, _, _).

regioes(Regioes) :-
    setof(R, I^A^S^B^F^Fu^C^segurado(I, A, S, B, F, Fu, R, C), Regioes).

regiao(Regiao) :-
    regioes(Regioes),
    member(Regiao, Regioes).

media(Lista, Media) :-
    Lista \= [],
    sum_list(Lista, Soma),
    length(Lista, N),
    Media is Soma / N.

percentual(Parte, Total, Pct) :-
    Total > 0,
    Pct is 100.0 * Parte / Total.


% 1. fumantes x nao fumantes

custo_medio_fumante(Fumante, Media) :-
    member(Fumante, [sim, nao]),
    findall(C, segurado(_, _, _, _, _, Fumante, _, C), Custos),
    media(Custos, Media).

premio_fumante(MediaFumante, MediaNaoFumante, Diferenca, Razao) :-
    custo_medio_fumante(sim, MediaFumante),
    custo_medio_fumante(nao, MediaNaoFumante),
    Diferenca is MediaFumante - MediaNaoFumante,
    Razao is MediaFumante / MediaNaoFumante.


% 2. ranking das regioes

custo_medio_regiao(Regiao, Media, N) :-
    regiao(Regiao),
    findall(C, segurado(_, _, _, _, _, _, Regiao, C), Custos),
    length(Custos, N),
    media(Custos, Media).

ranking_regioes(Ranking) :-
    setof(Media-Regiao, N^custo_medio_regiao(Regiao, Media, N), Crescente),
    reverse(Crescente, Ranking).

regiao_mais_cara(Regiao, Media) :-
    ranking_regioes([Media-Regiao | _]).

regiao_mais_barata(Regiao, Media) :-
    ranking_regioes(Ranking),
    last(Ranking, Media-Regiao).

taxa_fumantes_regiao(Regiao, Pct) :-
    custo_medio_regiao(Regiao, _, Total),
    findall(Id, (regiao_de(Id, Regiao), fumante(Id)), Fumantes),
    length(Fumantes, NFumantes),
    percentual(NFumantes, Total, Pct).


% 3. perfil de risco (faixa etaria + faixa de imc + fumante)

faixa_imc(Imc, abaixo_do_peso) :- Imc < 18.5.
faixa_imc(Imc, normal) :- Imc >= 18.5, Imc < 25.
faixa_imc(Imc, sobrepeso) :- Imc >= 25, Imc < 30.
faixa_imc(Imc, obesidade) :- Imc >= 30.

faixa_etaria(Idade, jovem) :- Idade < 30.
faixa_etaria(Idade, adulto) :- Idade >= 30, Idade < 50.
faixa_etaria(Idade, senior) :- Idade >= 50.

perfil(Id, perfil(FaixaEtaria, FaixaImc, Fumante)) :-
    segurado(Id, Idade, _, Imc, _, Fumante, _, _),
    faixa_etaria(Idade, FaixaEtaria),
    faixa_imc(Imc, FaixaImc).

perfis(Perfis) :-
    setof(P, Id^perfil(Id, P), Perfis).

% grupos muito pequenos distorcem a media, entao exijo pelo menos 10 segurados
tamanho_minimo_grupo(10).

custo_medio_perfil(Perfil, Media, N) :-
    perfis(Perfis),
    member(Perfil, Perfis),
    findall(C, (perfil(Id, Perfil), custo(Id, C)), Custos),
    length(Custos, N),
    tamanho_minimo_grupo(Min),
    N >= Min,
    media(Custos, Media).

ranking_perfis(Ranking) :-
    setof(Media-Perfil-N, custo_medio_perfil(Perfil, Media, N), Crescente),
    reverse(Crescente, Ranking).

perfil_mais_caro(Perfil, Media, N) :-
    ranking_perfis([Media-Perfil-N | _]).

perfil_mais_barato(Perfil, Media, N) :-
    ranking_perfis(Ranking),
    last(Ranking, Media-Perfil-N).


% 4. custos atipicos: mais que o dobro da media da propria regiao

fator_atipico(2).

custo_atipico(Id, Custo, Regiao, MediaRegiao) :-
    custo_medio_regiao(Regiao, MediaRegiao, _),
    segurado(Id, _, _, _, _, _, Regiao, Custo),
    fator_atipico(Fator),
    Custo > Fator * MediaRegiao.

total_atipicos(Total) :-
    findall(Id, custo_atipico(Id, _, _, _), Ids),
    length(Ids, Total).

qtd_atipicos_regiao(Regiao, Qtd, Pct) :-
    custo_medio_regiao(Regiao, _, Total),
    findall(Id, custo_atipico(Id, _, Regiao, _), Ids),
    length(Ids, Qtd),
    percentual(Qtd, Total, Pct).

fumantes_entre_atipicos(Pct) :-
    findall(Id, custo_atipico(Id, _, _, _), Ids),
    length(Ids, Total),
    include(fumante, Ids, Fumantes),
    length(Fumantes, NFumantes),
    percentual(NFumantes, Total, Pct).


% 5. os n segurados mais caros, com o perfil de cada um

top_n_custos(N, Top) :-
    setof(Custo-Id, custo(Id, Custo), Crescente),
    reverse(Crescente, Decrescente),
    length(Top0, N),
    append(Top0, _, Decrescente),
    findall(Custo-Id-Perfil, (member(Custo-Id, Top0), perfil(Id, Perfil)), Top).
