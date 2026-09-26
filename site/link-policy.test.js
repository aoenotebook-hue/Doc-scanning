const assert = require('node:assert/strict');
const {allowedAction} = require('./link-policy.js');

assert.equal(allowedAction('https://example.com/path').host, 'example.com');
assert.equal(allowedAction('mailto:person@example.com').host, 'Email');
assert.equal(allowedAction('tel:+66 123 456').host, 'Telephone');

for (const payload of [
  'plain text',
  'javascript:alert(1)',
  'data:text/html,test',
  'file:///secret',
  'intent://scan',
  'https://trusted.example@evil.example',
  'https://example.com%0ajavascript:alert(1)',
  'mailto:one@example.com,two@example.com',
  'mailto:one@example.com%0d%0aBcc:other@example.com',
]) assert.equal(allowedAction(payload), null, payload);

console.log('web link policy tests passed');
