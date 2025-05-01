export const mapsToArray = (maps: { [key: string]: unknown }[]) => {
	const set = new Set<string>()
	for (const map of maps) {
		for (const key in map) {
			set.add(key)
		}
	}
	return Array.from(set.values())
}

export const arrayUnion = (a: string[], b: string[]) => {
	const set = new Set<string>()
	for (const item of a) {
		set.add(item)
	}
	for (const item of b) {
		set.add(item)
	}
	return Array.from(set.values())
}

export const escapeRegex = (str: string) => {
	return str.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&")
}

function chunkSubstr(str: string, size: number) {
	const numChunks = Math.ceil(str.length / size)
	const chunks = new Array(numChunks)

	for (let i = 0, o = 0; i < numChunks; ++i, o += size) {
		chunks[i] = str.substr(o, size)
	}

	return chunks
}

