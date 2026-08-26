---
name: Bug report
about: The check reported the wrong thing, or would not run
labels: bug
---

**Command you ran**

```
android-16kb-check ...
```

**What it printed, and the exit code**

```
$ android-16kb-check ...
...
$ echo $?
```

<!-- The output matters more than a description of it, especially the
     `==> objdump` and `==> archive` lines: they say which tools were picked. -->

**What you expected instead**

<!-- If Play and this tool disagree, say which way round. "Play rejected an
     artifact this passed" and "this failed an artifact Play accepted" are very
     different bugs. -->

**Environment**

- OS:
- bash version (`bash --version`):
- NDK version, and how it was found (`--ndk`, `ANDROID_NDK_HOME`, `ANDROID_HOME`):
- `bundletool` or `zipalign` version:
- How the artifact was built (AGP version, Gradle, Flutter, other):
