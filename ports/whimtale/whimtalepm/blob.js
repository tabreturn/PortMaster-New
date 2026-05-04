import { randomUUID } from 'node:crypto';

// Map to store Blob URLs and their associated Blobs
const blobUrlRegistry = new Map();

// Simulate URL.createObjectURL
function createObjectURL(blob) {
  // console.log('createObjectURL', blob);
  const uniqueId = randomUUID(); // Generate a unique ID for the Blob
  const blobUrl = `blob:nodedata:${uniqueId}`;
  blobUrlRegistry.set(blobUrl, blob);
  return blobUrl;
}

// Simulate URL.revokeObjectURL
function revokeObjectURL(blobUrl) {
  if (blobUrlRegistry.has(blobUrl)) {
    blobUrlRegistry.delete(blobUrl);
  } else {
    console.warn(`Blob URL not found: ${blobUrl}`);
  }
}

// Simulate fetching data from a Blob URL
function fetchBlobFromUrl(blobUrl) {
  const blob = blobUrlRegistry.get(blobUrl);
  if (!blob) {
    throw new Error(`Blob not found for URL: ${blobUrl}`);
  }
  return blob;
}

export { createObjectURL, revokeObjectURL, fetchBlobFromUrl };
