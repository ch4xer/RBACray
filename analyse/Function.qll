import go
import Package

Function getParentFunction(Expr expr) { result = expr.getParent*().(FuncDecl).getFunction() }

class ControllerEntryFunction extends Function {
  ControllerEntryFunction() {
    this.getName() = "Sync" or
    this.getName() = "Reconcile"
  }
}

class EntryFunction extends Function {
  EntryFunction() {
    this.hasQualifiedName(_, "main") or
    this instanceof ControllerEntryFunction
  }
}

class InitFunction extends Function {
  InitFunction() { this.getName() = "init" }

  Package getActualPackage() {
    exists(PackagedFile pkgFile
      | this.getFuncDecl().getFile() = pkgFile
      | result = pkgFile.getPackage())
  }
}

predicate initCalling(EntryFunction entry, InitFunction init) {
  packageImports*(entry.getPackage(), init.getActualPackage())
}
