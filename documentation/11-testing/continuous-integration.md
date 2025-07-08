# Continuous Integration

## Overview

Continuous Integration (CI) for Awful.app ensures code quality, prevents regressions, and maintains stability throughout the SwiftUI migration. This document covers CI/CD pipelines, automated testing strategies, and quality gates.

## Current CI Setup

### GitHub Actions Configuration

#### Main CI Pipeline
```yaml
# .github/workflows/test.yml
name: CI

on:
  push:
    branches:
      - ci
      - main
  pull_request:
    branches:
      - main

jobs:
  test:
    runs-on: macos-13
    env:
      DEVELOPER_DIR: /Applications/Xcode_15.0.1.app/Contents/Developer
    
    steps:
    - uses: actions/checkout@v2
      with:
        submodules: recursive
    
    - name: Set up Xcode
      run: |
        sudo xcode-select -s /Applications/Xcode_15.0.1.app/Contents/Developer
        xcodebuild -version
    
    - name: Cache Swift Package Manager
      uses: actions/cache@v2
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Build and Test
      run: |
        xcodebuild -project Awful.xcodeproj \
          -scheme Awful \
          -configuration Debug \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          test
    
    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v2
      with:
        name: test-results
        path: |
          *.xcresult
          DerivedData/Logs/Test/*.xcresult
```

#### Enhanced CI Pipeline
```yaml
# .github/workflows/comprehensive-ci.yml
name: Comprehensive CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: SwiftLint
      run: |
        brew install swiftlint
        swiftlint --strict
    
    - name: SwiftFormat
      run: |
        brew install swiftformat
        swiftformat --lint .

  unit-tests:
    runs-on: macos-13
    strategy:
      matrix:
        destination:
          - "platform=iOS Simulator,name=iPhone 14,OS=latest"
          - "platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest"
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Select Xcode Version
      run: sudo xcode-select -s /Applications/Xcode_15.0.1.app/Contents/Developer
    
    - name: Cache Dependencies
      uses: actions/cache@v3
      with:
        path: |
          .build
          ~/Library/Developer/Xcode/DerivedData
        key: ${{ runner.os }}-deps-${{ hashFiles('**/Package.resolved', '**/*.xcodeproj') }}
    
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "Unit Tests" \
          -destination "${{ matrix.destination }}" \
          -enableCodeCoverage YES \
          -resultBundlePath "unit-test-results.xcresult"
    
    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        xcode: true
        xcode_archive_path: unit-test-results.xcresult

  integration-tests:
    runs-on: macos-13
    needs: unit-tests
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Run Integration Tests
      run: |
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "Integration Tests" \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          -resultBundlePath "integration-test-results.xcresult"

  ui-tests:
    runs-on: macos-13
    needs: unit-tests
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Run UI Tests
      run: |
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "UI Tests" \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          -resultBundlePath "ui-test-results.xcresult"
    
    - name: Upload Screenshots
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: ui-test-screenshots
        path: "**/*.png"

  performance-tests:
    runs-on: macos-13
    needs: unit-tests
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Run Performance Tests
      run: |
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "Performance Tests" \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          -resultBundlePath "performance-test-results.xcresult"
    
    - name: Analyze Performance Results
      run: |
        python3 scripts/analyze-performance.py performance-test-results.xcresult

  migration-tests:
    runs-on: macos-13
    needs: unit-tests
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Run Migration Tests
      run: |
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "Migration Tests" \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          -resultBundlePath "migration-test-results.xcresult"

  build-validation:
    runs-on: macos-13
    strategy:
      matrix:
        configuration: [Debug, Release]
        platform:
          - iOS
          - macOS
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Build for ${{ matrix.platform }} (${{ matrix.configuration }})
      run: |
        if [ "${{ matrix.platform }}" == "iOS" ]; then
          xcodebuild build \
            -project Awful.xcodeproj \
            -scheme Awful \
            -configuration ${{ matrix.configuration }} \
            -destination "generic/platform=iOS"
        else
          xcodebuild build \
            -project Awful.xcodeproj \
            -scheme "Awful macOS" \
            -configuration ${{ matrix.configuration }} \
            -destination "generic/platform=macOS"
        fi

  security-scan:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Run Security Scan
      run: |
        # Install security scanning tools
        brew install semgrep
        
        # Run security scan
        semgrep --config=auto --json --output=security-report.json .
    
    - name: Upload Security Report
      uses: actions/upload-artifact@v3
      with:
        name: security-report
        path: security-report.json
```

## Test Plans Configuration

### Unit Tests Plan
```json
{
  "configurations": [
    {
      "id": "UNIT_TESTS_CONFIG",
      "name": "Unit Tests Configuration",
      "options": {
        "codeCoverage": true,
        "targetForVariableExpansion": {
          "containerPath": "container:Awful.xcodeproj",
          "identifier": "1D6058900D05DD3D006BFB54",
          "name": "Awful"
        }
      }
    }
  ],
  "testTargets": [
    {
      "parallelizable": true,
      "target": {
        "containerPath": "container:AwfulCore",
        "identifier": "AwfulCoreTests",
        "name": "AwfulCoreTests"
      }
    },
    {
      "parallelizable": true,
      "target": {
        "containerPath": "container:AwfulExtensions",
        "identifier": "AwfulExtensionsTests",
        "name": "AwfulExtensionsTests"
      }
    },
    {
      "parallelizable": true,
      "target": {
        "containerPath": "container:AwfulScraping",
        "identifier": "AwfulScrapingTests",
        "name": "AwfulScrapingTests"
      }
    }
  ],
  "version": 1
}
```

### Integration Tests Plan
```json
{
  "configurations": [
    {
      "id": "INTEGRATION_TESTS_CONFIG",
      "name": "Integration Tests Configuration",
      "options": {
        "codeCoverage": false,
        "testTimeoutsEnabled": true,
        "defaultTestExecutionTimeAllowance": 600
      }
    }
  ],
  "testTargets": [
    {
      "target": {
        "containerPath": "container:Awful.xcodeproj",
        "identifier": "IntegrationTests",
        "name": "IntegrationTests"
      }
    }
  ],
  "version": 1
}
```

## Quality Gates

### Code Quality Checks

#### SwiftLint Configuration
```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - array_init
  - closure_spacing
  - contains_over_first_not_nil
  - empty_count
  - first_where
  - modifier_order
  - operator_usage_whitespace
  - redundant_nil_coalescing
  - sorted_first_last

included:
  - App
  - AwfulCore/Sources
  - AwfulExtensions/Sources
  - AwfulTheming/Sources
  - AwfulSettings/Sources

excluded:
  - Vendor
  - DerivedData
  - .build

line_length:
  warning: 120
  error: 200

function_body_length:
  warning: 60
  error: 100

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 1000

cyclomatic_complexity:
  warning: 10
  error: 20

reporter: "xcode"
```

#### Code Coverage Requirements
```swift
// Quality gate script
struct QualityGate {
    static let minimumCodeCoverage: Double = 75.0
    static let criticalComponentCoverage: Double = 90.0
    
    static let criticalComponents = [
        "AwfulCore",
        "Authentication",
        "DataPersistence",
        "HTMLScraping"
    ]
    
    static func validateCoverage(_ coverageReport: CoverageReport) -> Bool {
        // Overall coverage check
        guard coverageReport.overallCoverage >= minimumCodeCoverage else {
            print("❌ Overall coverage \(coverageReport.overallCoverage)% below minimum \(minimumCodeCoverage)%")
            return false
        }
        
        // Critical component coverage check
        for component in criticalComponents {
            guard let componentCoverage = coverageReport.componentCoverage[component],
                  componentCoverage >= criticalComponentCoverage else {
                print("❌ Critical component \(component) coverage below minimum \(criticalComponentCoverage)%")
                return false
            }
        }
        
        print("✅ All coverage requirements met")
        return true
    }
}
```

### Performance Gates

#### Performance Regression Detection
```python
#!/usr/bin/env python3
# scripts/analyze-performance.py

import json
import sys
from pathlib import Path

class PerformanceAnalyzer:
    def __init__(self):
        self.thresholds = {
            'launch_time': 3.0,  # seconds
            'memory_usage': 200 * 1024 * 1024,  # 200MB
            'cpu_usage': 80.0,  # percent
            'network_timeout': 10.0  # seconds
        }
        
        self.regression_threshold = 0.15  # 15% regression tolerance
    
    def analyze_results(self, xcresult_path):
        """Analyze performance test results"""
        results = self.parse_xcresult(xcresult_path)
        
        performance_data = {
            'launch_time': self.extract_launch_time(results),
            'memory_usage': self.extract_memory_usage(results),
            'cpu_usage': self.extract_cpu_usage(results),
            'network_timeout': self.extract_network_performance(results)
        }
        
        # Compare against baselines
        baselines = self.load_baselines()
        regressions = self.detect_regressions(performance_data, baselines)
        
        if regressions:
            print("❌ Performance regressions detected:")
            for metric, regression in regressions.items():
                print(f"  {metric}: {regression['current']:.2f} vs {regression['baseline']:.2f} ({regression['change']:.1f}% worse)")
            return False
        else:
            print("✅ No performance regressions detected")
            # Update baselines with current results
            self.update_baselines(performance_data)
            return True
    
    def detect_regressions(self, current, baselines):
        """Detect performance regressions"""
        regressions = {}
        
        for metric, current_value in current.items():
            if metric in baselines:
                baseline_value = baselines[metric]
                change = (current_value - baseline_value) / baseline_value
                
                if change > self.regression_threshold:
                    regressions[metric] = {
                        'current': current_value,
                        'baseline': baseline_value,
                        'change': change * 100
                    }
        
        return regressions

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: analyze-performance.py <xcresult_path>")
        sys.exit(1)
    
    analyzer = PerformanceAnalyzer()
    success = analyzer.analyze_results(sys.argv[1])
    sys.exit(0 if success else 1)
```

## Automated Testing

### Test Execution Scripts

#### Comprehensive Test Runner
```bash
#!/bin/bash
# scripts/run-tests.sh

set -e

# Configuration
PROJECT="Awful.xcodeproj"
SCHEME="Awful"
DESTINATION="platform=iOS Simulator,name=iPhone 14,OS=latest"
RESULTS_DIR="test-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_test_plan() {
    local test_plan=$1
    local output_file="${RESULTS_DIR}/${test_plan,,}-results.xcresult"
    
    print_status "Running $test_plan..."
    
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -testPlan "$test_plan" \
        -destination "$DESTINATION" \
        -enableCodeCoverage YES \
        -resultBundlePath "$output_file" \
        -quiet
    
    if [ $? -eq 0 ]; then
        print_status "$test_plan completed successfully"
        return 0
    else
        print_error "$test_plan failed"
        return 1
    fi
}

# Setup
print_status "Setting up test environment..."
mkdir -p "$RESULTS_DIR"
rm -rf "${RESULTS_DIR}"/*.xcresult

# Select Xcode version
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Clean build
print_status "Cleaning build..."
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -quiet

# Run test plans
test_plans=("Unit Tests" "Integration Tests" "Performance Tests")
failed_tests=()

for plan in "${test_plans[@]}"; do
    if ! run_test_plan "$plan"; then
        failed_tests+=("$plan")
    fi
done

# Generate reports
print_status "Generating test reports..."
python3 scripts/generate-test-report.py "$RESULTS_DIR"

# Summary
if [ ${#failed_tests[@]} -eq 0 ]; then
    print_status "All tests passed! ✅"
    exit 0
else
    print_error "The following test plans failed:"
    for plan in "${failed_tests[@]}"; do
        echo "  - $plan"
    done
    exit 1
fi
```

#### Parallel Test Execution
```bash
#!/bin/bash
# scripts/run-parallel-tests.sh

# Run different test types in parallel
run_unit_tests() {
    echo "Running unit tests..."
    xcodebuild test \
        -project Awful.xcodeproj \
        -scheme Awful \
        -testPlan "Unit Tests" \
        -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
        -resultBundlePath "unit-test-results.xcresult" \
        -quiet
}

run_integration_tests() {
    echo "Running integration tests..."
    xcodebuild test \
        -project Awful.xcodeproj \
        -scheme Awful \
        -testPlan "Integration Tests" \
        -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
        -resultBundlePath "integration-test-results.xcresult" \
        -quiet
}

run_ui_tests() {
    echo "Running UI tests..."
    xcodebuild test \
        -project Awful.xcodeproj \
        -scheme Awful \
        -testPlan "UI Tests" \
        -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
        -resultBundlePath "ui-test-results.xcresult" \
        -quiet
}

# Run tests in parallel
run_unit_tests &
UNIT_PID=$!

run_integration_tests &
INTEGRATION_PID=$!

run_ui_tests &
UI_PID=$!

# Wait for all tests to complete
wait $UNIT_PID
UNIT_RESULT=$?

wait $INTEGRATION_PID
INTEGRATION_RESULT=$?

wait $UI_PID
UI_RESULT=$?

# Check results
if [ $UNIT_RESULT -eq 0 ] && [ $INTEGRATION_RESULT -eq 0 ] && [ $UI_RESULT -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    [ $UNIT_RESULT -ne 0 ] && echo "  - Unit tests failed"
    [ $INTEGRATION_RESULT -ne 0 ] && echo "  - Integration tests failed"
    [ $UI_RESULT -ne 0 ] && echo "  - UI tests failed"
    exit 1
fi
```

### Migration-Specific CI

#### Migration Validation Pipeline
```yaml
name: Migration Validation

on:
  pull_request:
    paths:
      - 'App/**'
      - 'SwiftUI/**'
      - '**.swift'

jobs:
  migration-tests:
    runs-on: macos-13
    
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0  # Full history for comparison
    
    - name: Setup Migration Test Environment
      run: |
        # Create feature flag configuration for testing
        echo "MIGRATION_TESTING=true" >> migration.env
        echo "SWIFTUI_ENABLED=true" >> migration.env
        echo "FEATURE_FLAG_A_B_TESTING=true" >> migration.env
    
    - name: Run UIKit Baseline Tests
      run: |
        # Test current UIKit implementation
        FEATURE_FLAGS="SWIFTUI_ENABLED=false" \
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "Migration Baseline" \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          -resultBundlePath "uikit-baseline.xcresult"
    
    - name: Run SwiftUI Comparison Tests
      run: |
        # Test SwiftUI implementation
        FEATURE_FLAGS="SWIFTUI_ENABLED=true" \
        xcodebuild test \
          -project Awful.xcodeproj \
          -scheme Awful \
          -testPlan "Migration Comparison" \
          -destination "platform=iOS Simulator,name=iPhone 14,OS=latest" \
          -resultBundlePath "swiftui-comparison.xcresult"
    
    - name: Run Parity Validation
      run: |
        python3 scripts/validate-migration-parity.py \
          uikit-baseline.xcresult \
          swiftui-comparison.xcresult
    
    - name: Generate Migration Report
      run: |
        python3 scripts/generate-migration-report.py \
          --baseline uikit-baseline.xcresult \
          --comparison swiftui-comparison.xcresult \
          --output migration-report.html
    
    - name: Upload Migration Report
      uses: actions/upload-artifact@v3
      with:
        name: migration-report
        path: migration-report.html
```

## Test Result Analysis

### Test Report Generation

```python
#!/usr/bin/env python3
# scripts/generate-test-report.py

import subprocess
import json
import xml.etree.ElementTree as ET
from pathlib import Path

class TestReportGenerator:
    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.report_data = {
            'summary': {},
            'test_plans': {},
            'coverage': {},
            'performance': {}
        }
    
    def generate_report(self):
        """Generate comprehensive test report"""
        self.parse_all_results()
        self.analyze_coverage()
        self.analyze_performance()
        self.generate_html_report()
    
    def parse_all_results(self):
        """Parse all .xcresult bundles"""
        for xcresult in self.results_dir.glob("*.xcresult"):
            self.parse_xcresult(xcresult)
    
    def parse_xcresult(self, xcresult_path):
        """Parse individual .xcresult bundle"""
        # Extract test results using xcresulttool
        cmd = [
            "xcrun", "xcresulttool", "get",
            "--format", "json",
            "--path", str(xcresult_path)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            self.process_test_data(data)
    
    def analyze_coverage(self):
        """Analyze code coverage data"""
        # Extract coverage information
        coverage_cmd = [
            "xcrun", "xccov", "view",
            "--report", "--json"
        ]
        
        for xcresult in self.results_dir.glob("*.xcresult"):
            coverage_cmd.append(str(xcresult))
        
        result = subprocess.run(coverage_cmd, capture_output=True, text=True)
        if result.returncode == 0:
            coverage_data = json.loads(result.stdout)
            self.report_data['coverage'] = coverage_data
    
    def generate_html_report(self):
        """Generate HTML test report"""
        html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Awful App Test Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }
                .summary { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
                .passed { color: #28a745; }
                .failed { color: #dc3545; }
                .test-plan { margin-bottom: 30px; }
                .coverage-bar { background: #e9ecef; height: 20px; border-radius: 10px; overflow: hidden; }
                .coverage-fill { background: #28a745; height: 100%; }
            </style>
        </head>
        <body>
            <h1>Awful App Test Report</h1>
            {content}
        </body>
        </html>
        """
        
        content = self.build_html_content()
        html = html_template.format(content=content)
        
        with open(self.results_dir / "test-report.html", "w") as f:
            f.write(html)
    
    def build_html_content(self):
        """Build HTML content for report"""
        # Implementation would build detailed HTML report
        return "<p>Test report content would be generated here</p>"

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: generate-test-report.py <results_directory>")
        sys.exit(1)
    
    generator = TestReportGenerator(sys.argv[1])
    generator.generate_report()
    print("Test report generated successfully")
```

### Failure Analysis

```swift
// Test failure analysis for CI
struct TestFailureAnalyzer {
    static func analyzeFailures(in xcresultPath: String) -> FailureReport {
        let failures = extractFailures(from: xcresultPath)
        
        var report = FailureReport()
        
        for failure in failures {
            let category = categorizeFailure(failure)
            report.addFailure(failure, category: category)
        }
        
        return report
    }
    
    private static func categorizeFailure(_ failure: TestFailure) -> FailureCategory {
        let message = failure.message.lowercased()
        
        if message.contains("timeout") || message.contains("async") {
            return .timeout
        } else if message.contains("memory") || message.contains("leak") {
            return .memory
        } else if message.contains("ui") || message.contains("element") {
            return .ui
        } else if message.contains("network") || message.contains("connection") {
            return .network
        } else if message.contains("assertion") || message.contains("xcassert") {
            return .assertion
        } else {
            return .unknown
        }
    }
}

enum FailureCategory {
    case timeout
    case memory
    case ui
    case network
    case assertion
    case unknown
}

struct FailureReport {
    var categorizedFailures: [FailureCategory: [TestFailure]] = [:]
    
    mutating func addFailure(_ failure: TestFailure, category: FailureCategory) {
        if categorizedFailures[category] == nil {
            categorizedFailures[category] = []
        }
        categorizedFailures[category]?.append(failure)
    }
    
    func generateSummary() -> String {
        var summary = "Test Failure Summary:\n"
        
        for (category, failures) in categorizedFailures {
            summary += "\n\(category): \(failures.count) failures\n"
            for failure in failures.prefix(3) { // Show first 3
                summary += "  - \(failure.testName): \(failure.message)\n"
            }
            if failures.count > 3 {
                summary += "  ... and \(failures.count - 3) more\n"
            }
        }
        
        return summary
    }
}
```

## Notifications and Reporting

### Slack Integration

```python
#!/usr/bin/env python3
# scripts/notify-slack.py

import requests
import json
import sys
import os

class SlackNotifier:
    def __init__(self, webhook_url):
        self.webhook_url = webhook_url
    
    def send_test_results(self, test_status, details):
        """Send test results to Slack"""
        
        if test_status == "success":
            color = "good"
            emoji = "✅"
            title = "Tests Passed"
        else:
            color = "danger"
            emoji = "❌"
            title = "Tests Failed"
        
        payload = {
            "attachments": [
                {
                    "color": color,
                    "title": f"{emoji} {title}",
                    "fields": [
                        {
                            "title": "Branch",
                            "value": os.environ.get("GITHUB_REF", "unknown"),
                            "short": True
                        },
                        {
                            "title": "Commit",
                            "value": os.environ.get("GITHUB_SHA", "unknown")[:8],
                            "short": True
                        },
                        {
                            "title": "Details",
                            "value": details,
                            "short": False
                        }
                    ],
                    "footer": "Awful CI",
                    "ts": int(time.time())
                }
            ]
        }
        
        response = requests.post(self.webhook_url, json=payload)
        return response.status_code == 200

if __name__ == "__main__":
    webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
    if not webhook_url:
        print("SLACK_WEBHOOK_URL environment variable not set")
        sys.exit(1)
    
    notifier = SlackNotifier(webhook_url)
    
    status = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    details = sys.argv[2] if len(sys.argv) > 2 else "No details provided"
    
    success = notifier.send_test_results(status, details)
    sys.exit(0 if success else 1)
```

### Email Reporting

```python
#!/usr/bin/env python3
# scripts/email-report.py

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import os

class EmailReporter:
    def __init__(self, smtp_server, smtp_port, username, password):
        self.smtp_server = smtp_server
        self.smtp_port = smtp_port
        self.username = username
        self.password = password
    
    def send_test_report(self, recipients, test_results, attachments=None):
        """Send detailed test report via email"""
        
        msg = MIMEMultipart()
        msg['From'] = self.username
        msg['To'] = ", ".join(recipients)
        msg['Subject'] = f"Awful App Test Report - {test_results['status'].title()}"
        
        body = self.build_email_body(test_results)
        msg.attach(MIMEText(body, 'html'))
        
        # Add attachments
        if attachments:
            for attachment_path in attachments:
                self.add_attachment(msg, attachment_path)
        
        # Send email
        try:
            server = smtplib.SMTP(self.smtp_server, self.smtp_port)
            server.starttls()
            server.login(self.username, self.password)
            text = msg.as_string()
            server.sendmail(self.username, recipients, text)
            server.quit()
            return True
        except Exception as e:
            print(f"Failed to send email: {e}")
            return False
    
    def build_email_body(self, test_results):
        """Build HTML email body"""
        status_color = "#28a745" if test_results['status'] == 'success' else "#dc3545"
        
        html = f"""
        <html>
        <body style="font-family: Arial, sans-serif;">
            <h2 style="color: {status_color};">
                Test Results: {test_results['status'].title()}
            </h2>
            
            <h3>Summary</h3>
            <ul>
                <li><strong>Total Tests:</strong> {test_results.get('total_tests', 0)}</li>
                <li><strong>Passed:</strong> {test_results.get('passed_tests', 0)}</li>
                <li><strong>Failed:</strong> {test_results.get('failed_tests', 0)}</li>
                <li><strong>Coverage:</strong> {test_results.get('coverage_percent', 0)}%</li>
            </ul>
            
            <h3>Test Plans</h3>
            <table border="1" style="border-collapse: collapse; width: 100%;">
                <tr style="background-color: #f2f2f2;">
                    <th style="padding: 8px;">Test Plan</th>
                    <th style="padding: 8px;">Status</th>
                    <th style="padding: 8px;">Tests</th>
                    <th style="padding: 8px;">Duration</th>
                </tr>
        """
        
        for plan in test_results.get('test_plans', []):
            status_icon = "✅" if plan['status'] == 'passed' else "❌"
            html += f"""
                <tr>
                    <td style="padding: 8px;">{plan['name']}</td>
                    <td style="padding: 8px;">{status_icon} {plan['status']}</td>
                    <td style="padding: 8px;">{plan['test_count']}</td>
                    <td style="padding: 8px;">{plan['duration']}s</td>
                </tr>
            """
        
        html += """
            </table>
            
            <p>View the full report in the attached files.</p>
        </body>
        </html>
        """
        
        return html
```

## Best Practices

### CI Pipeline Design
- Fast feedback with parallel execution
- Fail fast on critical issues
- Comprehensive test coverage validation
- Clear, actionable failure reporting

### Test Organization
- Separate test plans for different test types
- Optimize test execution order
- Use appropriate timeouts and retry logic
- Maintain test environment consistency

### Quality Assurance
- Enforce code coverage minimums
- Validate performance regressions
- Check for security vulnerabilities
- Ensure accessibility compliance

### Monitoring and Alerting
- Real-time test result notifications
- Trend analysis for test reliability
- Performance baseline tracking
- Automated issue creation for failures

## Future Enhancements

### Planned Improvements
- Device farm integration for broader testing
- Visual regression testing automation
- Machine learning for test failure prediction
- Enhanced migration validation tools

### Tool Integration
- Firebase Test Lab integration
- TestFlight beta testing automation
- App Store Connect API integration
- Advanced performance monitoring