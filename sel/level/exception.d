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
module sel.level.exception;

class LevelException : Exception {
	
	public immutable uint code;
	
	this(uint code, string msg, string file=__FILE__, size_t line=__LINE__) {
		super(msg, file, line);
		this.code = code;
	}
	
}

class LevelInfoException : LevelException {
	
	enum : uint {
		
		BADLY_COMPRESSED = 1,
		WRONG_FORMAT = 2,
		WRONG_VALUE = 3,
		
	}
	
	this(uint code, string msg, string file=__FILE__, size_t line=__LINE__) {
		super(code, msg, file, line);
	}
	
}

class ChunkException : LevelException {
	
	enum : uint {
		
		INSUFFICIENT_DATA = 10,
		
	}
	
	this(uint code, string msg, string file=__FILE__, size_t line=__LINE__) {
		super(code, msg, file, line);
	}
	
}
