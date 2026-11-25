async function fetchHealth(fetchImpl) {
  const doFetch = fetchImpl || globalThis.fetch;
  const response = await doFetch("/api/health");
  if (!response.ok) {
    throw new Error(`Health check failed with status ${response.status}`);
  }
  return response.json();
}

module.exports = { fetchHealth };
