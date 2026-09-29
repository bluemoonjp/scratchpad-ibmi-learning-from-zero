path = 'src/qrpglesrc/jucsrv.rpgle'
with open(path, 'rb') as f:
    content = f.read()
nl = content.find(b'\n')
marker = b'// verify-rehearsal round-trip edit: this comment line only.\n'
content = content[:nl+1] + marker + content[nl+1:]
with open(path, 'wb') as f:
    f.write(content)
