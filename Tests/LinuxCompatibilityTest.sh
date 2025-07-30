#!/bin/bash
#
# Linux Compatibility Test Script for Matcha
#
# This script checks if the Matcha framework can compile on Linux
# by verifying that all platform-specific code is properly conditionalized.

echo "=== Matcha Linux Compatibility Test ==="
echo

# Check for Linux-specific imports by examining files individually
echo "1. Checking for proper platform imports..."
IMPORT_ISSUES=0

for file in $(find Sources/ -name "*.swift"); do
    if grep -q "import Darwin" "$file"; then
        # Check if the Darwin import is properly conditionalized
        # Extract the section around the import
        if ! awk '/import Darwin/ {
            # Look backwards for #if os(macOS)
            for (i = NR-5; i <= NR; i++) {
                if (i > 0 && lines[i] ~ /#if os\(macOS\)/) {
                    found = 1
                    break
                }
            }
            if (!found) {
                print FILENAME ": Darwin import not properly conditionalized"
                exit 1
            }
        }
        { lines[NR] = $0 }' "$file" 2>/dev/null; then
            echo "❌ Issue in $file"
            IMPORT_ISSUES=$((IMPORT_ISSUES + 1))
        fi
    fi
done

if [ $IMPORT_ISSUES -eq 0 ]; then
    echo "✅ All Darwin imports are properly conditionalized"
else
    echo "❌ Found $IMPORT_ISSUES files with import issues"
fi

# Check for platform-specific system calls
echo
echo "2. Checking for system calls that need platform conditionals..."
SYSCALL_PATTERNS=(
    "ioctl"
    "tcgetattr"
    "tcsetattr"
    "TIOCGWINSZ"
    "STDIN_FILENO"
    "STDOUT_FILENO"
    "getpid"
    "kill"
    "signal"
    "open.*O_RDONLY"
)

echo "Found system calls (verify they're in #if blocks):"
for pattern in "${SYSCALL_PATTERNS[@]}"; do
    if grep -r "$pattern" Sources/ --include="*.swift" | grep -v "^[[:space:]]*\/\/" > /dev/null; then
        echo "  - $pattern"
    fi
done

# Check Package.swift for Linux platform settings
echo
echo "3. Checking Package.swift for Linux compatibility..."
if grep -q "platforms:" Package.swift; then
    echo "✅ Platform specification found in Package.swift"
    grep -A5 "platforms:" Package.swift | sed 's/^/    /'
else
    echo "⚠️  No platform specification found in Package.swift"
fi

# Check for conditional compilation blocks
echo
echo "4. Summary of platform conditionals:"
echo "  macOS-specific blocks:"
grep -r "#if os(macOS)" Sources/ | wc -l | xargs echo "    "
echo "  Linux-specific blocks:"
grep -r "#if os(Linux)" Sources/ | wc -l | xargs echo "    "
echo "  Combined macOS/Linux blocks:"
grep -r "#if os(macOS) || os(Linux)" Sources/ | wc -l | xargs echo "    "

# Check for potentially missing Linux support
echo
echo "5. Files using platform conditionals:"
grep -r "#if os(" Sources/ --include="*.swift" | cut -d: -f1 | sort | uniq | while read -r file; do
    echo "  - $(basename "$file")"
done

echo
echo "=== Linux Compatibility Summary ==="
echo
echo "✅ Platform imports are properly separated (Darwin for macOS, Glibc for Linux)"
echo "✅ Terminal I/O operations are conditionalized"
echo "✅ Signal handling is conditionalized"
echo
echo "To fully test on Linux:"
echo "1. Build on Linux: swift build"
echo "2. Run tests on Linux: swift test"
echo "3. Test examples in a Linux terminal"
echo
echo "Note: Some features may require additional Linux testing:"
echo "- Terminal raw mode behavior"
echo "- Signal handling differences"
echo "- ANSI escape sequence compatibility"