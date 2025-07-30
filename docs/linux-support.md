# Linux Support

Matcha is designed to work on both macOS and Linux platforms. This document describes the platform-specific considerations and how to build and run Matcha on Linux.

## Platform Requirements

- **Swift**: 5.9 or later
- **Linux**: Any modern Linux distribution with glibc
- **Terminal**: Any terminal emulator with ANSI escape sequence support

## Building on Linux

```bash
# Clone the repository
git clone https://github.com/yourusername/matcha.git
cd matcha

# Build the project
swift build

# Run tests
swift test

# Build examples
swift build --target TextInput
swift build --target Counter
# ... etc
```

## Platform-Specific Implementation

### System Headers

The framework uses different system headers based on the platform:

- **macOS**: `import Darwin`
- **Linux**: `import Glibc`

### Terminal I/O

Terminal operations are implemented using POSIX APIs that are available on both platforms:

- `tcgetattr()` / `tcsetattr()` - Terminal attribute control
- `ioctl()` with `TIOCGWINSZ` - Terminal size detection
- `open()` / `read()` / `write()` - File operations
- Standard file descriptors: `STDIN_FILENO`, `STDOUT_FILENO`

### Signal Handling

Signal handling is implemented for both platforms:

- `SIGINT` (Ctrl+C) - Interrupt signal
- `SIGTSTP` (Ctrl+Z) - Terminal stop signal
- `SIGWINCH` - Window size change signal
- `SIGTERM` - Termination signal
- `SIGCONT` - Continue signal

### Conditional Compilation

Platform-specific code is wrapped in conditional compilation blocks:

```swift
#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

// Platform-specific code
#if os(macOS) || os(Linux)
    // POSIX-compliant code
#endif
```

## Testing on Linux

### Docker Testing

You can test Matcha on Linux using Docker:

```dockerfile
FROM swift:5.9-jammy

WORKDIR /app
COPY . .

RUN swift build
RUN swift test

# Run an example
CMD ["swift", "run", "Counter"]
```

### GitHub Actions

For CI/CD, you can test on both platforms:

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
runs-on: ${{ matrix.os }}
steps:
  - uses: actions/checkout@v3
  - uses: swift-actions/setup-swift@v1
  - run: swift build
  - run: swift test
```

## Known Differences

### Terminal Behavior

Some terminal behaviors may vary between macOS and Linux:

1. **Raw Mode**: The exact terminal flags and their effects may differ slightly
2. **Key Codes**: Some special key combinations may produce different codes
3. **Mouse Support**: Mouse protocol support depends on the terminal emulator

### Performance

Performance characteristics may differ:

- Signal handling latency
- Terminal I/O buffering
- Process scheduling

## Troubleshooting

### Common Issues

1. **Build Errors**: Ensure you have Swift 5.9+ installed
2. **Terminal Issues**: Check that your terminal supports ANSI escape sequences
3. **Permission Errors**: Some operations may require appropriate permissions

### Debug Output

Enable debug output to diagnose issues:

```bash
MATCHA_DEBUG=1 swift run YourApp
```

## Contributing

When contributing platform-specific code:

1. Always use conditional compilation for platform-specific features
2. Test on both macOS and Linux before submitting PRs
3. Document any platform-specific behavior
4. Prefer POSIX-compliant APIs when possible

## Platform Feature Matrix

| Feature | macOS | Linux | Notes |
|---------|--------|--------|--------|
| Terminal Raw Mode | ✅ | ✅ | POSIX termios |
| Terminal Size Detection | ✅ | ✅ | ioctl(TIOCGWINSZ) |
| Signal Handling | ✅ | ✅ | POSIX signals |
| Mouse Support | ✅ | ✅ | Terminal-dependent |
| Color Support | ✅ | ✅ | ANSI escape sequences |
| Unicode Support | ✅ | ✅ | UTF-8 |
| Alternate Screen | ✅ | ✅ | ANSI sequences |

## Future Improvements

- [ ] Add Windows support (using Windows Console API)
- [ ] Improve terminal capability detection
- [ ] Add terminfo database support
- [ ] Enhanced mouse protocol support