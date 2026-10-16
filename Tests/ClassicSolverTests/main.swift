let offered = uniqueDecisionActors([
    (2, 4),
    (0, 5),
    (1, 2),
    (0, 1),
    (3, 1),
    (2, 7),
    (0, 3),
    (1, 2),
])
let expected = [1, 3, 5, 2, 4, 7]
guard offered == expected else {
    fatalError("Expected every triggered actor once. Got \(offered).")
}
print("PASS all six triggered actors are offered once in stable order")
