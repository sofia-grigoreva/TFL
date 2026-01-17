-module(fuzzTest).
-export([main/0]).

%% ===================== DKA =====================

dka() ->
    [
        [1, 1],  % 0
        [2, 6],  % 1
        [3, 4],  % 2
        [2, 2],  % 3
        [2, 5],  % 4
        [1, 4],  % 5
        [6, 6]   % 6
    ].

dkaFinals() -> [true, false, true, false, false, true, false].

useDka(Word) ->
    useDkaLoop(Word, 0).

useDkaLoop([], State) ->
    {State, lists:nth(State + 1, dkaFinals())};
useDkaLoop([H|T], State) ->
    NextState = case H of
        $a -> lists:nth(1, lists:nth(State + 1, dka()));
        $b -> lists:nth(2, lists:nth(State + 1, dka()));
        _  -> -1
    end,
    case NextState of
        -1 -> {-1, false};
        _  -> useDkaLoop(T, NextState)
    end.


%% ===================== NKA =====================

nkaTransA() -> [[1],[2],[3],[],[],[]].
nkaTransB() -> [[1],[],[],[2],[5],[4]].
nkaTransEps() -> [[],[],[0,4],[],[0],[]].
nkaFinals() -> [0].
nkaStart() -> 0.

epsClosure(States) ->
    epsClosureLoop(States, States).

epsClosureLoop([], Closure) -> Closure;
epsClosureLoop([S|Stack], Closure) ->
    Next = lists:nth(S + 1, nkaTransEps()),
    NewStates = [T || T <- Next, not lists:member(T, Closure)],
    epsClosureLoop(Stack ++ NewStates, Closure ++ NewStates).

useNka(Word) ->
    Cur = epsClosure([nkaStart()]),
    useNkaLoop(Word, Cur).

useNkaLoop([], Cur) ->
    anyFinals(Cur, nkaFinals());
useNkaLoop([H|T], Cur) ->
    NextSet = lists:flatten([case H of
                                $a -> lists:nth(S + 1, nkaTransA());
                                $b -> lists:nth(S + 1, nkaTransB())
                            end || S <- Cur]),
    case NextSet of
        [] -> false;
        _  -> useNkaLoop(T, epsClosure(NextSet))
    end.

anyFinals(Cur, Finals) ->
    lists:any(fun(S) -> lists:member(S, Finals) end, Cur).


%% ===================== PKA =====================

pkaTrans() ->
    [
        #{$a => [1], $b => [1]},  % 0
        #{$a => [2]},              % 1
        #{$a => [3], $b => [3]},   % 2
        #{$a => [2], $b => [2]},   % 3
        #{$a => [5], $b => [7]},   % 4
        #{$a => [4], $b => [6]},   % 5
        #{$a => [5], $b => [9]},   % 6
        #{$a => [4], $b => [8]},   % 7
        #{$a => [10], $b => [9]},  % 8
        #{$a => [4], $b => [8]},   % 9
        #{$a => [4], $b => [11]},  % 10
        #{$a => [11], $b => [11]}, % 11
        #{}                        % 12
    ].

pkaFinals() -> [0,2,4,6,8,10].
pkaStartStates() -> [0,4].

useBranch(Start, Word) ->
    useBranchLoop([Start], Word).

useBranchLoop(Cur, []) ->
    lists:any(fun(S) -> lists:member(S, pkaFinals()) end, Cur);
useBranchLoop(Cur, [H|T]) ->
    NextSet = lists:flatten([maps:get(H, lists:nth(S+1, pkaTrans()), []) || S <- Cur]),
    case NextSet of
        [] -> false;
        _  -> useBranchLoop(NextSet, T)
    end.

usePka(Word) ->
    lists:all(fun(S) -> useBranch(S, Word) end, pkaStartStates()).


%% ===================== Остальное =====================

generateRandomWord(Length) ->
    [randomLetter() || _ <- lists:seq(1,Length)].

randomLetter() ->
    case rand:uniform(2) of
        1 -> $a;
        2 -> $b
    end.


main() ->
    N = 500,
    Regex = "^(.a(ab)*(bb)*)*$",
    rand:seed(exsplus, os:timestamp()),
    mainLoop(1, 30, N, Regex),
    io:format("--------------------------------------------------~nВсе тесты выполнены!~n").

mainLoop(Length, Max, N, Regex) when Length < Max ->
    lists:foreach(fun(_) ->
        Word = generateRandomWord(Length),
        {_, DkaRes} = useDka(Word),
        NkaRes = useNka(Word),
        PkaRes = usePka(Word),
        RegexRes = case re:run(lists:flatten(Word), Regex) of
               {match, _} -> true;
               nomatch -> false
           end,
        if DkaRes =/= NkaRes orelse NkaRes =/= PkaRes orelse PkaRes =/= RegexRes ->
               io:format("ОШИБКА! Слово: ~s~n", [lists:flatten(Word)]),
               erlang:halt(1);
           true -> ok
        end
    end, lists:seq(1,N)),
    io:format("--------------------------------------------------~nУСПЕШНО, Длина: ~p, Количество: ~p~n", [Length,N]),
    mainLoop(Length + 1, Max, N, Regex);
mainLoop(_,_,_,_) -> ok.
