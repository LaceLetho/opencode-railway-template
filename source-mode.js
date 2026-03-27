function isSourceMode(env) {
  const value = env?.SOURCE_MODE;
  if (value === undefined) return true;
  return String(value).toLowerCase() !== "false";
}

module.exports = {
  isSourceMode,
};
