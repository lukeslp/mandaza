package com.lukesteuber.mandaza.core

data class MandazaPalette(
    val id: String,
    val name: String,
    val colors: List<Long>,
) {
    fun colorAt(value: Double): Long {
        val t = value.coerceIn(0.0, 0.99999)
        val segment = t * (colors.size - 1)
        val index = segment.toInt()
        val fraction = segment - index
        return lerp(colors[index], colors[index + 1], fraction)
    }

    private fun lerp(a: Long, b: Long, t: Double): Long {
        fun channel(color: Long, shift: Int) = ((color shr shift) and 0xff).toDouble()
        fun mix(shift: Int) = (channel(a, shift) + (channel(b, shift) - channel(a, shift)) * t)
            .toLong().coerceIn(0, 255)
        return 0xff000000L or (mix(16) shl 16) or (mix(8) shl 8) or mix(0)
    }
}

object MandazaPalettes {
    val all = listOf(
        palette("aurora", "Aurora", "3c096c", "5a189a", "9d4edd", "48bfe3", "80ffdb"),
        palette("sunset", "Sunset", "ff006e", "fb5607", "ffbe0b", "fee440", "fff3b0"),
        palette("ember", "Ember", "370617", "9d0208", "dc2f02", "f48c06", "ffba08"),
        palette("bioluminescent", "Bioluminescent", "03045e", "0077b6", "00b4d8", "48cae4", "caf0f8"),
        palette("vaporwave", "Vaporwave", "ff71ce", "b967ff", "01cdfe", "05ffa1", "fffb96"),
        palette("cyberpunk", "Cyberpunk", "ff006e", "fb5607", "ffbe0b", "8338ec", "3a86ff"),
        palette("risograph", "Risograph", "ff5e5b", "ffed66", "00cecb", "5c5cff"),
        palette("oxblood", "Oxblood", "1a0a0c", "3d0c11", "7a1722", "c1292e", "f1d4af"),
        palette("canopy", "Canopy", "012210", "064e29", "0ea047", "39ff14", "b2ff87"),
        palette("dichromat", "Dichromat", "0072b2", "56b4e9", "f0e442", "e69f00", "d55e00"),
        palette("amber", "Amber", "1f1000", "522e0a", "a55a17", "dba34a", "fdd99b"),
        palette("terrain", "Terrain", "1a0f05", "7c3810", "c47830", "6b7c45", "c8d4a0"),
    )

    fun byId(id: String): MandazaPalette = all.firstOrNull { it.id == id }
        ?: when (id) {
            "riso" -> all.first { it.id == "risograph" }
            "arctic" -> all.first { it.id == "canopy" }
            else -> all.first()
        }

    private fun palette(id: String, name: String, vararg hex: String) = MandazaPalette(
        id = id,
        name = name,
        colors = hex.map { 0xff000000L or it.toLong(16) },
    )
}
