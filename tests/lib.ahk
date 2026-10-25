; Included by every test script: an error is printed and ends the test, never a dialog.
OnError(TestError)
TestError(e, *) {
    FileAppend("error: " e.Message " (" e.What ", line " e.Line ")`n", "*")
    ExitApp(2)
}
