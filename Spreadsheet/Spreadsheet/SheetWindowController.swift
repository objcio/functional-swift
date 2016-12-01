import Cocoa

class SheetWindowController: NSWindowController {
    @IBOutlet var tableView: NSTableView! = nil
    @IBOutlet var dataSource: SpreadsheetDatasource?
    @IBOutlet var delegate: SpreadsheetDelegate?

    override func windowDidLoad()  {
        delegate?.editedRowDelegate = dataSource
        NotificationCenter.default.addObserver(self, selector: NSSelectorFromString("endEditing:"), name: NSNotification.Name.NSControlTextDidEndEditing, object: nil)
    }

    func endEditing(_ note: Notification) {
        guard note.object as? NSObject === tableView else { return }
        dataSource?.editedRow = nil
    }
}


protocol EditedRow: class {
    var editedRow: Int? { get set }
}


class SpreadsheetDelegate: NSObject, NSTableViewDelegate {
    weak var editedRowDelegate: EditedRow?

    func tableView(_ aTableView: NSTableView, shouldEdit aTableColumn: NSTableColumn?, row rowIndex: Int) -> Bool {
        editedRowDelegate?.editedRow = rowIndex
        return true
    }
}


class SpreadsheetDatasource: NSObject, NSTableViewDataSource, EditedRow {
    var formulas: [String]
    var results: [Result]
    var editedRow: Int? = nil

    override init() {
        let initialValues = Array(1..<10)
        formulas = initialValues.map { "\($0)" }
        results = initialValues.map { .int($0) }
    }

    func parseAndEvaluate() {
        let expressions = formulas.map { Expression.parser.parse($0.characters)?.0 }
        results = evaluate(expressions: expressions)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return formulas.count
    }

    func tableView(_ aTableView: NSTableView, objectValueFor objectValueForTableColumn: NSTableColumn?, row: Int) -> Any? {
        return editedRow == row ? formulas[row] : results[row].description
    }

    func tableView(_ tableView: NSTableView, setObjectValue: Any?, for forTableColumn: NSTableColumn?, row: Int) {
        guard let string = setObjectValue as? String else { fatalError() }
        formulas[row] = string
        parseAndEvaluate()
        tableView.reloadData()
    }
}


extension Result: CustomStringConvertible {
    var description: String {
        switch (self) {
        case .int(let x):
            return "\(x)"
        case .list(let x):
            return String(describing: x)
        case .error(let e):
            return "Error: \(e)"
        }
    }
}
