import "@testing-library/jest-dom";

// Tell React we are running inside a concurrent-mode act() environment
// so async state-update warnings are suppressed in tests.
declare global {
  // eslint-disable-next-line no-var
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
