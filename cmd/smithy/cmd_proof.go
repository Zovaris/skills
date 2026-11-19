package main

import "github.com/Zovaris/smithy/internal/proof"

func init() {
	register("receipt", "run a command and record it as evidence for a claim", proof.ReceiptMain)
	register("scan", "check a change's added lines and files for secrets", proof.ScanMain)
}
