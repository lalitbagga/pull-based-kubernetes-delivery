import assert from 'node:assert/strict'
import { mkdtemp, readFile, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'

import { updateDigest } from '../update-gitops-digest.mjs'

const oldDigest = `sha256:${'0'.repeat(64)}`
const newDigest = `sha256:${'a'.repeat(64)}`

async function fixture(contents) {
  const directory = await mkdtemp(join(tmpdir(), 'delivery-api-promotion-'))
  const filePath = join(directory, 'values.yaml')
  await writeFile(filePath, contents, 'utf8')
  return filePath
}

test('updates exactly one digest without changing surrounding YAML', async () => {
  const filePath = await fixture(`image:\n  repository: example.invalid/delivery-api\n  digest: ${oldDigest}\nconfig:\n  readinessMode: ready\n`)

  await updateDigest(filePath, newDigest)

  assert.equal(
    await readFile(filePath, 'utf8'),
    `image:\n  repository: example.invalid/delivery-api\n  digest: ${newDigest}\nconfig:\n  readinessMode: ready\n`
  )
})

test('rejects a mutable tag', async () => {
  const filePath = await fixture(`image:\n  digest: ${oldDigest}\n`)
  await assert.rejects(updateDigest(filePath, 'latest'), /Invalid image digest/)
})

test('rejects a file with more than one digest', async () => {
  const filePath = await fixture(`first:\n  digest: ${oldDigest}\nsecond:\n  digest: ${oldDigest}\n`)
  await assert.rejects(updateDigest(filePath, newDigest), /found 2/)
})

test('rejects a file with no digest', async () => {
  const filePath = await fixture('image:\n  repository: example.invalid/delivery-api\n')
  await assert.rejects(updateDigest(filePath, newDigest), /found 0/)
})
