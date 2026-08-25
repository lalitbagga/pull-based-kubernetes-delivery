#!/usr/bin/env node

import { readFile, writeFile } from 'node:fs/promises'

const digestPattern = /^sha256:[a-f0-9]{64}$/
const digestLinePattern = /^(\s+digest:\s+)sha256:[a-f0-9]{64}(\s*)$/gm

export async function updateDigest(filePath, digest) {
  if (!digestPattern.test(digest)) {
    throw new Error(`Invalid image digest: ${digest}`)
  }

  const current = await readFile(filePath, 'utf8')
  const matches = [...current.matchAll(digestLinePattern)]

  if (matches.length !== 1) {
    throw new Error(`Expected exactly one image digest in ${filePath}; found ${matches.length}`)
  }

  const updated = current.replace(digestLinePattern, `$1${digest}$2`)
  await writeFile(filePath, updated, 'utf8')
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [, , filePath, digest] = process.argv

  if (!filePath || !digest) {
    console.error('Usage: update-gitops-digest.mjs <values-file> <sha256:digest>')
    process.exit(2)
  }

  updateDigest(filePath, digest).catch((error) => {
    console.error(error.message)
    process.exit(1)
  })
}
