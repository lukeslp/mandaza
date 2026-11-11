// Loop construction adapted from Dillon (Dillo), Controlled loops on hexagons /
// Loops on hexagons (MIT). See LICENSES/ and docs/FDROID_PROVENANCE.md.
package com.lukesteuber.mandaza.core

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

private object HexConst {
    val s = sqrt(3.0)
    val xs = doubleArrayOf(-0.5, 0.5, 1.0, 0.5, -0.5, -1.0)
    val ys = doubleArrayOf(-s / 2, -s / 2, 0.0, s / 2, s / 2, 0.0)
    val xperp = doubleArrayOf(0.0, -s / 2, -s / 2, 0.0, s / 2, s / 2)
    val yperp = doubleArrayOf(1.0, 0.5, -0.5, -1.0, -0.5, 0.5)
    val dxOdd = arrayOf(
        intArrayOf(-1, -1, 0, 1, 0, -1),
        intArrayOf(-1, 0, 1, 1, 1, 0),
    )
    val dxAny = intArrayOf(0, 1, 1, 0, -1, -1)
}

private val probabilityTable = arrayOf(
    intArrayOf(0, 1, 0, 0),
    intArrayOf(0, 0, 1, 0),
    intArrayOf(0, 0, 0, 1),
    intArrayOf(0, 1, 1, 0),
    intArrayOf(0, 1, 0, 1),
    intArrayOf(0, 0, 2, 1),
    intArrayOf(0, 1, 3, 1),
)

// Dillon's wrapper over the GRC/Steve Gibson Mash variant (public domain),
// based on Johannes Baagøe's Mash (MIT). See THIRD_PARTY_NOTICES.md.
private class Mash(seed: String) {
    private var n = 0xefc8249dL

    init {
        seed.codePoints().forEach { absorb(it.toLong()) }
    }

    private fun absorb(value: Long) {
        n = (n + value) and 0xffffffffL
        var h = 0.02519603282416938 * n.toDouble()
        n = h.toLong() and 0xffffffffL
        h -= n.toDouble()
        h *= n.toDouble()
        n = h.toLong() and 0xffffffffL
        h -= n.toDouble()
        n = (n + (h * 4_294_967_296.0).toLong()) and 0xffffffffL
    }

    fun next(): Double {
        absorb('A'.code.toLong())
        return n.toDouble() * 2.3283064365386963e-10
    }

    fun int(maximum: Int): Int = if (maximum <= 0) 0 else floor(next() * maximum).toInt()
    fun between(minimum: Double, maximum: Double) = minimum + next() * (maximum - minimum)
}

private class Dot(val cell: Cell, val edge: Int, val index: Int) {
    var x = 0.0
    var y = 0.0
    var other: Dot? = null
    var loop: WorkLoop? = null
    var closed = false
    val point get() = MandazaPoint(x, y)
}

private class Cell(val kx: Int, val ky: Int) {
    val odd = kx and 1
    val neighbors = arrayOfNulls<Cell>(6)
    val dotCounts = IntArray(6)
    val dots = Array(6) { mutableListOf<Dot>() }
    var flatDots = mutableListOf<Dot>()
    var connectables = mutableListOf<MutableList<Dot>>()
    var active = mutableListOf<Dot>()
    var centerX = 0.0
    var centerY = 0.0
    var vertices = emptyList<MandazaPoint>()
}

private class WorkLoop {
    val pairs = mutableListOf<Pair<Dot, Dot>>()
    var curves = emptyList<MandazaCubic>()
    var closed = false
    var start: Dot? = null
}

class MandazaEngine(private val config: EngineConfig = EngineConfig()) {
    private var width = 0.0
    private var height = 0.0
    private var radius = 0.0
    private var columns = 0
    private var rows = 0
    private var offsetX = 0.0
    private var offsetY = 0.0
    private var grid = emptyList<List<Cell>>()
    private lateinit var randomStructure: Mash
    private lateinit var randomGeneration: Mash
    private var internalRegularity = 5.0

    fun generate(width: Double, height: Double, seed: String): GeneratedMandaza {
        require(width > 1 && height > 1) { "Canvas must have positive dimensions" }
        require(config.isValidForExternalRendering) { "Unsafe Mandaza configuration" }
        this.width = width
        this.height = height
        randomStructure = Mash("$seed/struct")
        randomGeneration = Mash("$seed/gen")
        internalRegularity = if (config.regularity <= 5) config.regularity
        else 5 + (95.0 / 5.0) * (config.regularity - 5)
        check(buildGrid()) { "Unable to build Mandaza grid" }
        val loops = buildLoops().filter { it.curves.isNotEmpty() }
        return GeneratedMandaza(
            width = width,
            height = height,
            radius = radius,
            seed = seed,
            loops = loops.mapIndexed { index, loop ->
                MandazaLoop(loop.curves, index, loops.size)
            },
        )
    }

    private fun buildGrid(): Boolean {
        val target = if (config.cellSizeRandom) randomGeneration.between(10.0, 100.0)
        else sqrt(config.density) * 10.0 + (1 - sqrt(config.density)) * 100.0
        var candidate = sqrt(((width * height) / target) * 2 / 3 / HexConst.s)
        var valid = false
        var attempts = 0
        while (!valid && attempts < 100) {
            if (config.withMargin) {
                columns = floor(((width - 20) / candidate + 0.5) / 1.5).toInt()
                rows = floor((height - 20) / candidate / HexConst.s - 0.5).toInt() + 1
            } else {
                columns = ceil((width / candidate - 0.5) / 1.5).toInt() + 1
                rows = ceil(height / candidate / HexConst.s + 0.5).toInt()
            }
            if (columns > 1 && rows > 1) {
                valid = true
            } else {
                candidate *= 0.95
            }
            attempts++
        }
        if (!valid) return false
        radius = candidate
        offsetX = (width - radius * (0.5 + 1.5 * columns)) / 2 + radius
        offsetY = (height - radius * HexConst.s * (0.5 + rows)) / 2 + radius * HexConst.s / 2
        grid = List(rows) { y -> List(columns) { x -> Cell(x, y) } }
        grid.flatten().forEach(::setNeighbors)

        val geometry = if (config.randomPattern) randomGeneration.int(probabilityTable.size)
        else config.geometry.coerceIn(0, probabilityTable.lastIndex)
        val urn = buildList {
            probabilityTable[geometry].forEachIndexed { count, frequency ->
                repeat(frequency) { add(count) }
            }
        }
        grid.flatten().forEach { cell ->
            repeat(6) { direction ->
                if (cell.dotCounts[direction] != 0) return@repeat
                val neighbor = cell.neighbors[direction] ?: return@repeat
                val opposite = (direction + 3) % 6
                val pick = urn[randomStructure.int(urn.size)]
                cell.dotCounts[direction] = pick
                neighbor.dotCounts[opposite] = pick
            }
        }

        val oddCells = grid.flatten().filter { it.dotCounts.sum() and 1 == 1 }
        grid.flatten().forEach { cell ->
            repeat(6) { direction ->
                val count = cell.dotCounts[direction]
                if (count == 0 || cell.dots[direction].isNotEmpty()) return@repeat
                val neighbor = cell.neighbors[direction] ?: return@repeat
                val opposite = (direction + 3) % 6
                val here = MutableList(count) { index -> Dot(cell, direction, index) }
                val there = MutableList(count) { index -> Dot(neighbor, opposite, index) }
                here.forEachIndexed { index, dot ->
                    val mirror = there[count - 1 - index]
                    dot.other = mirror
                    mirror.other = dot
                }
                cell.dots[direction].addAll(here)
                neighbor.dots[opposite].addAll(there)
            }
        }
        grid.flatten().forEach { it.flatDots = it.dots.flatMapTo(mutableListOf()) { edge -> edge } }
        if (oddCells.isNotEmpty() && !closeOne(oddCells, 0)) return false
        grid.flatten().forEach(::sizeCell)
        grid.flatten().forEach { cell ->
            val alive = cell.flatDots.filterNot { it.closed }.toMutableList()
            cell.connectables = mutableListOf(alive)
            cell.active = alive.toMutableList()
        }
        return true
    }

    private fun setNeighbors(cell: Cell) {
        repeat(6) { direction ->
            val x = cell.kx + HexConst.dxAny[direction]
            val y = cell.ky + HexConst.dxOdd[cell.odd][direction]
            cell.neighbors[direction] = if (y in grid.indices && x in grid[y].indices) grid[y][x] else null
        }
    }

    private fun sizeCell(cell: Cell) {
        cell.centerX = offsetX + cell.kx * 1.5 * radius
        cell.centerY = offsetY + cell.ky * radius * HexConst.s + 0.5 * cell.odd * radius * HexConst.s
        cell.vertices = List(6) { index ->
            MandazaPoint(
                cell.centerX + HexConst.xs[index] * radius,
                cell.centerY + HexConst.ys[index] * radius,
            )
        }
        repeat(6) { edge ->
            val count = cell.dotCounts[edge]
            val fractions = when (count) {
                1 -> doubleArrayOf(0.5)
                2 -> doubleArrayOf(3.0 / 8.0, 5.0 / 8.0)
                3 -> doubleArrayOf(9.0 / 32.0, 0.5, 23.0 / 32.0)
                else -> doubleArrayOf()
            }
            fractions.forEachIndexed { index, fraction ->
                val point = lerp(cell.vertices[edge], cell.vertices[(edge + 1) % 6], fraction)
                cell.dots[edge][index].x = point.x
                cell.dots[edge][index].y = point.y
            }
        }
    }

    private fun closeOne(cells: List<Cell>, index: Int): Boolean {
        val candidates = cells[index].flatDots.toMutableList()
        while (candidates.isNotEmpty()) {
            val dot = candidates.removeAt(randomStructure.int(candidates.size))
            if (dot.other == null || dot.other?.closed != true) {
                dot.closed = true
                if (index == cells.lastIndex || closeOne(cells, index + 1)) return true
                dot.closed = false
            }
        }
        return false
    }

    private fun buildLoops(): List<WorkLoop> {
        val loops = mutableListOf<WorkLoop>()
        var cell = if (config.centered) grid[(rows - 1) / 2][(columns - 1) / 2]
        else grid[randomStructure.int(rows)][randomStructure.int(columns)]
        var attempts = 0
        while (cell.connectables.firstOrNull().isNullOrEmpty()) {
            cell = grid[randomStructure.int(rows)][randomStructure.int(columns)]
            if (++attempts > 2000) return emptyList()
        }
        loops += makeLoop(cell.connectables.first()[cell.connectables.first().size / 2])

        var index = 0
        while (index < loops.size) {
            val loop = loops[index]
            var found: Dot? = null
            for ((first, second) in loop.pairs) {
                found = nextClockwise(first.cell, first)
                    ?: nextCounterClockwise(second.cell, second)
                    ?: nextCounterClockwise(first.cell, first)
                    ?: nextClockwise(second.cell, second)
                if (found != null) break
            }
            if (found != null) loops += makeLoop(found) else index++
        }
        grid.flatten().forEach { candidate ->
            candidate.active.filter { it.loop == null }.forEach { dot -> loops += makeLoop(dot) }
        }
        return loops
    }

    private fun makeLoop(start: Dot): WorkLoop {
        val loop = WorkLoop().also { it.start = start }
        while (extend(loop, true)) {
            if (loop.pairs.first().first.other === loop.pairs.last().second) {
                loop.closed = true
                break
            }
        }
        if (!loop.closed) while (extend(loop, false)) Unit
        loop.pairs.forEach { (a, b) -> a.loop = loop; b.loop = loop }
        loop.curves = loop.pairs.map { (a, b) -> cellToBezier(a.cell, a, b) }
        return loop
    }

    private fun extend(loop: WorkLoop, direct: Boolean): Boolean {
        val incoming = when {
            loop.pairs.isEmpty() -> loop.start ?: return false
            direct -> loop.pairs.last().second.other ?: return false
            else -> loop.pairs.first().first.other ?: return false
        }
        if (incoming.closed) return false
        val outgoing = pickNext(incoming.cell, incoming, direct) ?: return false
        if (direct) loop.pairs += incoming to outgoing else loop.pairs.add(0, outgoing to incoming)
        return true
    }

    private fun pickNext(cell: Cell, incoming: Dot, direct: Boolean): Dot? {
        cell.connectables.indices.forEach { connectionIndex ->
            val list = cell.connectables[connectionIndex]
            val start = list.indexOfFirst { it === incoming }
            if (start < 0) return@forEach
            val count = list.size
            val end = if (config.concentric && randomStructure.int(internalRegularity.toInt()) != 0) {
                if (direct) (start + 1) % count else (start + count - 1) % count
            } else {
                randomStructure.int(count / 2) * 2 + ((start and 1) xor 1)
            }
            val outgoing = list[end]
            val low = min(start, end)
            val high = max(start, end)
            val extracted = list.subList(low, high + 1).toList()
            repeat(high - low + 1) { list.removeAt(low) }
            val middle = extracted.drop(1).dropLast(1).toMutableList()
            if (middle.isNotEmpty()) cell.connectables += middle
            if (list.isEmpty()) cell.connectables.removeAt(connectionIndex)
            return outgoing
        }
        return null
    }

    private fun nextClockwise(cell: Cell, dot: Dot): Dot? {
        if (cell.active.isEmpty()) return null
        val index = cell.active.indexOfFirst { it === dot }
        if (index < 0) return null
        return cell.active[(index + 1) % cell.active.size].takeIf { it.loop == null }
    }

    private fun nextCounterClockwise(cell: Cell, dot: Dot): Dot? {
        if (cell.active.isEmpty()) return null
        val index = cell.active.indexOfFirst { it === dot }
        if (index < 0) return null
        return cell.active[(index + cell.active.size - 1) % cell.active.size].takeIf { it.loop == null }
    }

    private fun cellToBezier(cell: Cell, input: Dot, output: Dot): MandazaCubic {
        val incoming = input.edge
        val outgoing = output.edge
        val difference = abs(outgoing - incoming)
        val start = input.point
        val end = output.point
        val controls = when (difference) {
            0 -> {
                val distance = 0.2 * radius
                offset(start, incoming, distance) to offset(end, outgoing, distance)
            }
            1, 5 -> {
                val shared = if (outgoing - incoming == -1 || outgoing - incoming == 5) incoming else outgoing
                val inDistance = distance(cell.vertices[shared], start)
                val outDistance = distance(cell.vertices[shared], end)
                offset(start, incoming, 0.75 * outDistance) to offset(end, outgoing, 0.75 * inDistance)
            }
            2, 4 -> offset(start, incoming, 0.6 * radius) to offset(end, outgoing, 0.6 * radius)
            else -> offset(start, incoming, 0.5 * radius) to offset(end, outgoing, 0.5 * radius)
        }
        return MandazaCubic(start, controls.first, controls.second, end)
    }

    private fun offset(point: MandazaPoint, edge: Int, distance: Double) = MandazaPoint(
        point.x + HexConst.xperp[edge] * distance,
        point.y + HexConst.yperp[edge] * distance,
    )

    private fun lerp(a: MandazaPoint, b: MandazaPoint, t: Double) = MandazaPoint(
        t * b.x + (1 - t) * a.x,
        t * b.y + (1 - t) * a.y,
    )

    private fun distance(a: MandazaPoint, b: MandazaPoint) = hypot(b.x - a.x, b.y - a.y)
}
