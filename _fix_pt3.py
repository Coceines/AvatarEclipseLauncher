import re

with open('data/locales/pt.lua', 'rb') as f:
    data = f.read()

text = data.decode('cp1252')
lines = text.split('\n')
fixed = []

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.rstrip()
    
    # Check if this line has an unclosed Lua string (starts a key or value)
    # Count quotes to detect if string is unclosed
    in_string = False
    quote_char = None
    escaped = False
    quote_count = 0
    for ch in stripped:
        if escaped:
            escaped = False
            continue
        if ch == '\\':
            escaped = True
            continue
        if ch in ('"', "'"):
            quote_count += 1
    
    # If odd number of quotes, the string is unclosed - join with next line
    if quote_count % 2 == 1:
        combined = stripped
        while i + 1 < len(lines):
            i += 1
            next_stripped = lines[i].rstrip()
            # Add escaped newline in Lua string
            combined = combined + '\\n' + next_stripped
            # Check if quotes are now balanced
            qc = 0
            esc = False
            for ch in combined:
                if esc:
                    esc = False
                    continue
                if ch == '\\':
                    esc = True
                    continue
                if ch in ('"', "'"):
                    qc += 1
            if qc % 2 == 0:
                break
        fixed.append(combined)
    else:
        fixed.append(stripped)
    i += 1

result = '\n'.join(fixed) + '\n'

with open('data/locales/pt.lua', 'wb') as f:
    f.write(result.encode('cp1252'))

# Verify
with open('data/locales/pt.lua', 'rb') as f:
    check = f.read()
check_lines = check.split(b'\n')
bad = 0
for i, line in enumerate(check_lines, 1):
    if not line.strip():
        continue
    qc = 0
    esc = False
    for ch in line.decode('cp1252', errors='replace'):
        if esc:
            esc = False
            continue
        if ch == '\\':
            esc = True
            continue
        if ch == '"':
            qc += 1
    if qc % 2 == 1:
        print(f"UNBALANCED Line {i}: {line[:100]}")
        bad += 1

print(f"\nTotal lines: {len(check_lines)}, unbalanced: {bad}")

# Check for replacement chars
repl_count = check.count(b'\xef\xbf\xbd')
print(f"Replacement chars: {repl_count}")
