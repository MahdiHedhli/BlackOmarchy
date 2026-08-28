# VM tests

Connection details are not in this repository. Copy
`local.env.example` to `local.env` (gitignored) on the operator
machine.

VM A is for iterative bootstrap. VM B stays clean until the candidate
is ready. The final pass on VM B must:

1. Follow README install steps as written
2. Compare the Omarchy baseline
3. Reboot into the graphical session
4. Run representative `core` tools
5. Run a real `omarchy update`
6. Run uninstall

```bash
cp tests/vm/local.env.example tests/vm/local.env
# fill in values locally
./tests/vm/run-remote.sh
```
