/**
 * Validation reporter with optional GitHub Actions annotations.
 */

const isCI = !!process.env.CI || !!process.env.GITHUB_ACTIONS;

export class Reporter {
  constructor(name) {
    this.name = name;
    this.errors = 0;
    this.warnings = 0;
    this._checks = 0;
  }

  header() {
    console.log(`\n🔍 ${this.name}`);
    console.log("─".repeat(60));
  }

  tick() {
    this._checks++;
  }

  ok(...args) {
    if (args.length === 1) {
      console.log(`  ✅ ${args[0]}`);
    } else {
      console.log(`  ✅ ${args[0]}: ${args[1]}`);
    }
  }

  error(...args) {
    this.errors++;
    if (args.length === 1) {
      console.log(`  ❌ ${args[0]}`);
    } else {
      console.log(`  ❌ ${args[0]}: ${args[1]}`);
    }
  }

  warn(...args) {
    this.warnings++;
    if (args.length === 1) {
      console.log(`  ⚠️  ${args[0]}`);
    } else {
      console.log(`  ⚠️  ${args[0]}: ${args[1]}`);
    }
  }

  check(description, condition, severity = "error") {
    if (condition) {
      this.ok(description);
    } else if (severity === "warn") {
      this.warn(description);
    } else {
      this.error(description);
    }
  }

  errorAnnotation(filePath, msg) {
    if (isCI) {
      console.log(`::error file=${filePath}::${msg}`);
    }
    this.error(filePath, msg);
  }

  warnAnnotation(filePath, msg) {
    if (isCI) {
      console.log(`::warning file=${filePath}::${msg}`);
    }
    this.warn(filePath, msg);
  }

  summary(label) {
    const prefix = label ? `${label}: ` : "";
    console.log("");
    console.log(
      `${prefix}${this._checks} checked, ${this.errors} error(s), ${this.warnings} warning(s)`,
    );
  }

  exitOnError(passMsg, failMsg) {
    if (this.errors > 0) {
      if (failMsg) console.log(`\n❌ ${failMsg}`);
      else
        console.log(`\n❌ ${this.name} failed with ${this.errors} error(s).`);
      process.exit(1);
    } else {
      if (passMsg) console.log(`\n✅ ${passMsg}`);
      else console.log(`\n✅ ${this.name} passed.`);
    }
  }
}
