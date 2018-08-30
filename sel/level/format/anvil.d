﻿/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright © 2017-2018 SEL
 * License: LGPL-3.0
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/sel-level/sel/level/anvil.d, sel/level/anvil.d)
 */
module sel.level.format.anvil;

import std.bitmanip : peek;
import std.conv : to, ConvException;
import std.file : exists, read, write;
import std.path : dirSeparator;
import std.system : Endian;
import std.typetuple : TypeTuple;
import std.zlib : Compress, UnCompress, HeaderFormat, ZlibException;

import sel.level.data;
import sel.level.exception;
import sel.level.level : Level, readLevelInfoCompound, writeLevelInfoCompound;
import sel.level.util;

import sel.nbt;
import sel.nbt.file : JavaLevelFormat;

import xbuffer : Buffer;

import std.stdio : writeln; // debug

private alias LevelInfoValues = TypeTuple!(
	String, "name", "LevelName",
	Long, "seed", "RandomSeed",
	Int, "gamemode", "GameType",
	Int, "difficulty", "Difficulty",
	Byte, "hardcore", "hardcore",
	Long, "time", "Time",
	Long, "dayTime", "DayTime",
	Int, "spawn.x", "SpawnX",
	Int, "spawn.y", "SpawnY",
	Int, "spawn.z", "SpawnZ",
	Byte, "raining", "raining",
	Int, "rainTime", "rainTime",
	Byte, "thundering", "thundering",
	Int, "thunderTime", "thunderTime",
	Byte, "commandsAllowed", "allowCommands",
);

abstract class AbstractAnvil : Level {

	private JavaLevelFormat infoReader;

	private Chunk[Vector2!int] chunks;
	private ubyte[][Vector2!int] regions;

	public this(string path) {
		super(path);
		this.infoReader = new JavaLevelFormat(this.path ~ "level.dat");
	}

	protected override LevelInfo readLevelInfo() {
		Compound compound;
		try {
			compound = this.infoReader.load();
		} catch(ZlibException) {
			throw new LevelInfoException(LevelInfoException.BADLY_COMPRESSED, "Level info was badly compressed");
		}
		enforce!LevelInfoException(compound !is null, LevelInfoException.WRONG_FORMAT, "Root tag is not a compound");
		enforce!LevelInfoException(compound.has!Compound("Data"), LevelInfoException.WRONG_FORMAT, "Compound has no data tag");
		LevelInfo ret = readLevelInfoCompound!LevelInfoValues(cast(Compound)compound["Data"]);
		foreach(gamerule ; compound.getValue!Compound("GameRules", [])) {
			if(cast(String)gamerule) {
				immutable value = (cast(String)gamerule).value;
				if(value == "true") {
					ret.gamerules[gamerule.name] = LevelInfo.GameRule(true);
				} else if(value == "false") {
					ret.gamerules[gamerule.name] = LevelInfo.GameRule(false);
				} else {
					try {
						ret.gamerules[gamerule.name] = LevelInfo.GameRule(to!int(value));
					} catch(ConvException) {
						throw new LevelInfoException(LevelInfoException.WRONG_VALUE, "Gamerule " ~ gamerule.name ~ " cannot be converted to integer");
					}
				}
			}
		}
		return ret;
	}

	protected override void writeLevelInfo(LevelInfo levelInfo) {
		auto data = writeLevelInfoCompound!LevelInfoValues(levelInfo);
		if(levelInfo.gamerules.length) {
			auto compound = new Named!Compound("GameRules");
			foreach(name, gamerule; levelInfo.gamerules) {
				compound[] = new Named!String(name, gamerule.isBool ? to!string(gamerule.bool_) : to!string(gamerule.int_));
			}
			data[] = compound;
		}
		this.infoReader.tag = new Compound(data.rename("Data"));
		this.infoReader.save();
	}

	protected override Chunk readChunkImpl(Dimension dimension, Vector2!int position) {
		auto savedChunk = position in chunks;
		if(savedChunk) return *savedChunk;
		Vector2!int regionPosition = Vector2!int(position.x >> 5, position.z >> 5);
		immutable file = this.path ~ dimensionPath(dimension) ~ dirSeparator ~ "r." ~ regionPosition.x.to!string ~ "." ~ regionPosition.z.to!string ~ ".mca";
		if(exists(file)) {
			// region exists
			ubyte[] data = cast(ubyte[])read(file);
			if(data.length > 8192) {
				// region may be valid
				immutable infoOffset = ((position.x & 31) + (position.z & 31) * 32) * 4;
				immutable info = peek!uint(data, infoOffset);
				immutable timestamp = peek!uint(data, infoOffset + 4096);
				if(info != 0) {
					// chunk exists
					immutable offset = (info >> 8) * 4096;
					Buffer buffer = new Buffer(data[offset..offset+(info & 255)*4096]);
					immutable length = buffer.read!(Endian.bigEndian, uint)();
					assert(buffer.read!ubyte() == 2); // compression type
					UnCompress uncompress = new UnCompress();
					const(void)[] ucd = uncompress.uncompress(buffer.readData(length-1));
					ucd ~= uncompress.flush();
					buffer.data = ucd;
					Compound compound = cast(Compound)new ClassicStream!(Endian.bigEndian)(buffer).readTag();
					if(compound !is null) {
						Chunk chunk = new Chunk(position, timestamp, compound);
						Compound level = compound.get!Compound("Level", null);
						if(level !is null) {
							if(level.has!IntArray("Biomes")) chunk.biomes = cast(IntArray)level["Biomes"];
							if(level.has!List("Sections")) {
								foreach(sectionList ; cast(List)level["Sections"]) {
									Compound sectionCompound = cast(Compound)sectionList;
									assert(sectionCompound.has!List("Palette"));
									assert(sectionCompound.has!LongArray("BlockStates"));
									string[] palette;
									foreach(paletteValue ; cast(List)sectionCompound["Palette"]) {

									}
									if(sectionCompound.has!LongArray("BlockStates")) {
										buffer.data = [];
										foreach(value ; cast(LongArray)sectionCompound["BlockStates"]) {
											buffer.write!(Endian.bigEndian)(value);
										}
										writeln(buffer.data);
									}
								}
							}
						}
						return chunk;
					}
				}
			}
		}
		return null;
	}

	protected override Chunk[Vector2!int] readChunksImpl(Dimension dimension) {
		//TODO read chunks
		this.regions.clear();
		return this.chunks;
	}

	private static string dimensionPath(Dimension dimension) {
		if(dimension.java == 0) return "region";
		else return "DIM" ~ dimension.java.to!string ~ dirSeparator ~ "data";
	}

}

class AnvilImpl(string order) : AbstractAnvil { //TODO validate coordinates
	
	public this(string path) {
		super(path);
	}

}

alias Anvil = AnvilImpl!"yzx";

unittest {

	Level anvil = new Anvil("test/Anvil");

	with(anvil.levelInfo) {
		assert(name == "New World");
		assert(seed == 608293555344486561L);
		assert(gamemode == 1);
		assert(hardcore == false);
		assert(time == 15388);
		assert(dayTime == 15388);
		assert(spawn.x == 8);
		assert(spawn.y == 64);
		assert(spawn.z == 224);
		assert(commandsAllowed == true);
	}

	Chunk chunk = anvil.readChunk(0, 0);

	assert(chunk !is null);

	assert(chunk.biomes[0] == 0);
	assert(chunk.biomes[$-1] == 7);

}