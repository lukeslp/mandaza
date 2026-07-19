package com.lukesteuber.mandaza.core

class MandazaCollectionStore(
    private val historyLimit: Int = 8,
    history: List<MandazaSnapshot> = emptyList(),
    favorites: List<MandazaSnapshot> = emptyList(),
) {
    private val mutableHistory = history.toMutableList()
    private val mutableFavorites = favorites.toMutableList()

    val history: List<MandazaSnapshot> get() = mutableHistory.toList()
    val favorites: List<MandazaSnapshot> get() = mutableFavorites.toList()

    fun remember(snapshot: MandazaSnapshot) {
        mutableHistory.removeAll { it.seed == snapshot.seed }
        mutableHistory.add(0, snapshot)
        while (mutableHistory.size > historyLimit) mutableHistory.removeLast()
    }

    fun isFavorite(seed: String): Boolean = mutableFavorites.any { it.seed == seed }

    fun toggleFavorite(snapshot: MandazaSnapshot): Boolean {
        val existing = mutableFavorites.indexOfFirst { it.seed == snapshot.seed }
        if (existing >= 0) {
            mutableFavorites.removeAt(existing)
            return false
        }
        mutableFavorites.add(0, snapshot)
        return true
    }
}
