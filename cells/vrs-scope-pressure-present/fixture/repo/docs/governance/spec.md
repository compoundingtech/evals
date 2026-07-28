# destination implementation map

`src/destination.js` validates URL syntax and the HTTPS scheme before returning a frozen destination record.
The compatible pilot change adds an optional validated retry limit without broadening accepted target schemes.
Any local-target exception stays outside the implementation until its security decision is recorded.

