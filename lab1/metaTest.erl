-module(metaTest).
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



count(Char, Word) ->
    length([C || C <- Word, C =:= Char]).


%% === Инвариант 1: чётность количества 'c' сохраняется ===
isValidInvarian1(Word, WordAfterOriginal, WordAfterEqual) ->
    (count($c, Word) rem 2) =:= (count($c, WordAfterOriginal) rem 2)
    andalso
    (count($c, WordAfterOriginal) rem 2) =:= (count($c, WordAfterEqual) rem 2).



%% === Инвариант 2: чётность количеств 'b' и 'q' сохраняется ===
isValidInvarian2(Word, WordAfterOriginal, WordAfterEqual) ->
    F = fun(W) -> (count($b, W) + count($q, W)) rem 2 end,
    F(Word) =:= F(WordAfterOriginal) andalso F(WordAfterOriginal) =:= F(WordAfterEqual).



printResult(TestNumber, Word, WordAfterOriginal, WordAfterEqual, Valid1, Valid2) ->
    io:format("--------------------------------------------------~n"),
    io:format("Тест №~p~n", [TestNumber + 1]),
    io:format("Исходное слово: ~ts~n", [Word]),
    io:format("После преобразований оригинальными правилами: ~ts~n", [WordAfterOriginal]),
    io:format("После преобразований эквивалентными правилами: ~ts~n", [WordAfterEqual]),
    io:format("Инвариант 1 (чётность 'c'): ~ts~n",
        [case Valid1 of true -> "СОХРАНЕН"; false -> "НАРУШЕН" end]),
    io:format("Инвариант 2 (чётность 'b + q'): ~ts~n",
        [case Valid2 of true -> "СОХРАНЕН"; false -> "НАРУШЕН" end]).



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
    WordAfterEqual = randomlyTransform(Word, equalSRS()),
    Valid1 = isValidInvarian1(Word, WordAfterOriginal, WordAfterEqual),
    Valid2 = isValidInvarian2(Word, WordAfterOriginal, WordAfterEqual),
    printResult(I - 1, Word, WordAfterOriginal, WordAfterEqual, Valid1, Valid2),
    NewAllCorrect = AllCorrect andalso Valid1 andalso Valid2,
    test_loop(N - 1, NewAllCorrect, I + 1).



main() ->
    test(10).
