-module(fuzzTest).
-export([main/0]).

-define(ALPHABET, "abcdpq").

originalSRS() ->
    [
        {"apbc", "caqdbapbap"},
        {"paqd", "daqdbapbap"},
        {"ccpp", "adaqdqa"},
        {"dpd", "pdp"}
    ].

equalSRS() ->
    [
        {"caqdbapbap", "apbc"},
        {"daqdbapbap", "paqd"},
        {"adaqdqa", "ccpp"},
        {"pdp", "dpd"},
        {"caqdbapbadpd", "apbcdp"},
        {"daqdbapbadpd", "paqddp"},
        {"pddpd", "dpddp"}
    ].


generateRandomWord() ->
    Length = rand:uniform(21) + 9,
    generateRandomWord(Length, []).

generateRandomWord(0, Acc) ->
    lists:reverse(Acc);
generateRandomWord(N, Acc) ->
    Char = lists:nth(rand:uniform(length(?ALPHABET)), ?ALPHABET),
    generateRandomWord(N - 1, [Char | Acc]).



findOccurrences(Sub, Word) ->
    findOccurrences(Sub, Word, 1, []).

findOccurrences(_Sub, [], _Index, Acc) ->
    lists:reverse(Acc);
findOccurrences(Sub, Word, Index, Acc) ->
    case lists:prefix(Sub, Word) of
        true -> findOccurrences(Sub, tl(Word), Index + 1, [Index | Acc]);
        false -> findOccurrences(Sub, tl(Word), Index + 1, Acc)
    end.



randomlyTransform(Word, Rules) ->
    Steps = rand:uniform(10),
    randomlyTransform(Word, Rules, Steps).

randomlyTransform(Word, _Rules, 0) ->
    Word;
randomlyTransform(Word, Rules, Steps) ->
    PossibleChanges = [
        {Index, Left, Right} ||
            {Left, Right} <- Rules,
            Index <- findOccurrences(Left, Word)
    ],
    case PossibleChanges of
        [] -> Word;
        _ ->
            {Index, Left, Right} = lists:nth(rand:uniform(length(PossibleChanges)), PossibleChanges),
            {LeftPart, Rest} = lists:split(Index - 1, Word),
            Trimmed = lists:nthtail(length(Left), Rest),
            NewWord = LeftPart ++ Right ++ Trimmed,
            randomlyTransform(NewWord, Rules, Steps - 1)
    end.



getNext(Word, Rules) ->
    NextSet = lists:foldl(fun({Left, Right}, Acc) ->
        lists:foldl(fun(Index, Acc2) ->
            {LeftPart, Rest} = lists:split(Index - 1, Word),
            Trimmed = lists:nthtail(length(Left), Rest),
            NewWord = LeftPart ++ Right ++ Trimmed,
            sets:add_element(NewWord, Acc2)
        end, Acc, findOccurrences(Left, Word))
    end, sets:new(), Rules),
    sets:to_list(NextSet).



findTransformOptions(StartWord, Rules) ->
    bfs([StartWord], sets:add_element(StartWord, sets:new()), Rules).



bfs([], Visited, _Rules) -> sets:to_list(Visited);
bfs([Cur | Queue], Visited, Rules) ->
    NextWords = getNext(Cur, Rules),
    NewWords = [W || W <- NextWords, not sets:is_element(W, Visited)],
    NewVisited = lists:foldl(fun(W, Acc) -> sets:add_element(W, Acc) end, Visited, NewWords),
    bfs(Queue ++ NewWords, NewVisited, Rules).



isSameExist(StartWord, Rules, Targets) ->
    bfsExist([StartWord], sets:add_element(StartWord, sets:new()), Rules, sets:from_list(Targets)).



bfsExist([], _Visited, _Rules, _Targets) -> false;
bfsExist([Cur | Queue], Visited, Rules, Targets) ->
   case sets:is_element(Cur, Targets) of
    true -> true;
    false ->
        NextWords = getNext(Cur, Rules),
        NewWords = [W || W <- NextWords, not sets:is_element(W, Visited)],
        NewVisited = lists:foldl(fun(W, Acc) -> sets:add_element(W, Acc) end, Visited, NewWords),
        bfsExist(Queue ++ NewWords, NewVisited, Rules, Targets)
end.



getWordsInOrder(Word1, Word2) ->
    L1 = length(Word1), L2 = length(Word2),
    case L1 < L2 of
        true -> {Word1, Word2};
        false -> case L1 > L2 of
                    true -> {Word2, Word1};
                    false -> if Word1 =< Word2 -> {Word1, Word2}; true -> {Word2, Word1} end
                 end
    end.



areEqual(Small, Big) ->
    Targets = findTransformOptions(Small, equalSRS()),
    isSameExist(Big, equalSRS(), Targets).



printResult(TestNumber, Word, WordAfterOriginal, AreEquivalent) ->
    io:format("--------------------------------------------------~n"),
    io:format("Тест №~p~n", [TestNumber]),
    io:format("Исходное слово: ~ts~n", [Word]),
    io:format("После преобразований оригинальными правилами: ~ts~n", [WordAfterOriginal]),
    io:format("Эквивалентны: ~ts~n", [case AreEquivalent of true -> "ДА"; false -> "НЕТ" end]).



test(TestsNumber) ->
    rand:seed(exsplus, {erlang:monotonic_time(), erlang:unique_integer([monotonic]), erlang:phash2(self())}),
    io:format("Запуск ~p тестов~n", [TestsNumber]),
    AllCorrect = test_loop(TestsNumber, true, 1),
    io:format("--------------------------------------------------~n"),
    case AllCorrect of
        true -> io:format("SRS ЭКВИВАЛЕНТНЫ~n");
        false -> io:format("SRS НЕ ЭКВИВАЛЕНТНЫ~n")
    end.

test_loop(0, AllCorrect, _) -> AllCorrect;
test_loop(N, AllCorrect, I) ->
    Word = generateRandomWord(),
    WordAfterOriginal = randomlyTransform(Word, originalSRS()),
    {Small, Big} = getWordsInOrder(Word, WordAfterOriginal),
    AreEquivalent = areEqual(Small, Big),
    NewAllCorrect = AllCorrect andalso AreEquivalent,
    printResult(I, Word, WordAfterOriginal, AreEquivalent),
    test_loop(N - 1, NewAllCorrect, I + 1).



main() ->
    test(10).
