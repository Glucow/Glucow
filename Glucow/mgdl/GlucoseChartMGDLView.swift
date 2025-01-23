import SwiftUI
import Charts



struct GlucoseChartMGDLView: View {
    let dataPoints: [(date: Date, value: Double)]
    
    // Boundaries (mmol if useMmol == true, mg/dL if false)
    let veryLowRange: ClosedRange<Double>
    let lowRange: ClosedRange<Double>
    let inRange: ClosedRange<Double>
    let highRange: ClosedRange<Double>
    let veryHighRange: ClosedRange<Double>
    
    let useMmol: Bool
    
    
    // MARK: - Convert mg/dL => mmol if needed (no longer being used)
//    private var convertedDataPoints: [(date: Date, value: Double)] {
//    @AppStorage("selectedUnit") var selectedUnit: String = "mmol/L"
        
//        if selectedUnit == "mmol/L" {
//            let converted = dataPoints.map { ($0.date, $0.value * 18.0) }
//            print("Converted Data Points (mg/dL):", converted)
//            return converted
 //       } else {
//            let converted = dataPoints.map { ($0.date, $0.value) }
//            print("Converted Data Points (mg/dL):", converted)
//            return converted
//        }
//    }
    
    var body: some View {
        
        let points = dataPoints
        
        
        Chart {
            
            // 2) Big dots
            ForEach(points, id: \.date) { dp in
                PointMark(
                    x: .value("Time", dp.date),
                    y: .value("Glucose", dp.value)
                )
                .symbolSize(45)
                .foregroundStyle(colorForValue(dp.value))
            }
            
            // 3) Dotted lines for user boundaries
            boundaryRule("Very Low",  fixedVeryLowLine(), .red)
            boundaryRule("Low",       fixedLowLine(),     .green)
            boundaryRule("RangemgdL",       fixedrangemgdlLine(),     .yellow)
            boundaryRule("In Range",  fixedRangeLine(),      .yellow)
            boundaryRule("High",      fixedHighLine(),    .yellow)
            boundaryRule("Fixed Top", fixedTopLine(), .red)
            boundaryRule("Fixed Bottom", fixedBottomLine(), .red)
            
            RuleMark(x: .value("Right Edge", xDomain().upperBound.addingTimeInterval(75)))
                .lineStyle(StrokeStyle(lineWidth: 1.3))
                .foregroundStyle(.gray)
                .offset(y: 0)
            
            RuleMark(y: .value("Bottom Edge", 40))
                .lineStyle(StrokeStyle(lineWidth: 1.3))
                .foregroundStyle(.gray)
            
            let connectingLineData = [
                (date: xDomain().upperBound, value: 40), // Start of the line
                (date: xDomain().upperBound.addingTimeInterval(75), value: 40) // End of the line
            ]
            ForEach(connectingLineData, id: \.date) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Glucose", point.value)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.3))
                .foregroundStyle(.gray)
                
            }
            
        }
        // X-axis => last 3 hours
        .chartXScale(domain: xDomain())
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime
                    .hour(.defaultDigits(amPM: .omitted))
                    .minute())
            }
        }
        
        .chartYScale(domain: yDomain())
        // Hide default Y ticks
        .chartYAxis {
            AxisMarks { }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .padding(.trailing, 30) // Space for boundary labels
        }
        .frame(height: 340)
        .padding(.horizontal, 16)
    }
    
    
    // MARK: - X Domain => last 3 hours
    private func xDomain() -> ClosedRange<Date> {
        let now = Date()
        let threeHoursAgo = Calendar.current.date(byAdding: .hour, value: -3, to: now)!
        return threeHoursAgo ... now
    }
    
    // MARK: - Y Domain
    private func yDomain() -> ClosedRange<Double> {
        let points = dataPoints
        
        let dataMin = points.map(\.value).min() ?? 0
        let dataMax = points.map(\.value).max() ?? 0
        
        let lower = max(40.0, min(dataMin, 40.0)) // Ensure floor is at least 40
        let top: Double
        if dataMax > 430 {
            top = 500
        } else if dataMax > 390 {
            top = 430
        } else if dataMax > 300 {
            top = 390
        } else {
            top = 300
        }
        return lower ... max(top, dataMax)
    }
    
    // A fixed top line at 15 mmol
    private func fixedTopLine() -> Double {
        return 300
    }
    
    private func fixedBottomLine() -> Double {
        return 40
    }
    
    private func fixedMaxHighLine() -> Double {
        return 500
    }
    
    private func fixedrangemgdlLine() -> Double {
        return 72
    }
    
    private func fixedVeryVeryHighLine() -> Double {
        return 430
    }
    
    private func fixedVeryHighLine() -> Double {
        return 390
    }
    
    private func fixedHighLine() -> Double {
        return 300
    }
    
    private func fixedRangeLine() -> Double {
        return 234
    }
    
    private func fixedLowLine() -> Double {
        return 153
    }
    
    private func fixedVeryLowLine() -> Double {
        return 50
    }
    
    // MARK: - boundaryRule
    @ChartContentBuilder
    private func boundaryRule(_ title: String, _ val: Double, _ color: Color) -> some ChartContent {
        RuleMark(y: .value(title, val))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(color.opacity(0.8))
            .annotation(position: .trailing) {
                Text(useMmol ? String(format: "%.1f", val) : String(format: "%.0f", val))
                    .font(.caption2)
                    .foregroundColor(color)
                    .padding(.horizontal, 4)
            }
    }
    
    // MARK: - colorForValue
    private func colorForValue(_ val: Double) -> Color {
        // Ensure ranges are scaled to mg/dL
        let veryLowRangeMgdl = veryLowRange.lowerBound * 18.0...veryLowRange.upperBound * 18.0
        let lowRangeMgdl = lowRange.lowerBound * 18.0...lowRange.upperBound * 18.0
        let inRangeMgdl = inRange.lowerBound * 18.0...inRange.upperBound * 18.0
        let highRangeMgdl = highRange.lowerBound * 18.0...highRange.upperBound * 18.0
        let veryHighRangeMgdl = veryHighRange.lowerBound * 18.0...veryHighRange.upperBound * 18.0
        
        // Determine color based on ranges in mg/dL
        if veryLowRangeMgdl.contains(val) {
            return .red
        } else if lowRangeMgdl.contains(val) {
            return .yellow
        } else if inRangeMgdl.contains(val) {
            return .green
        } else if highRangeMgdl.contains(val) {
            return .yellow
        } else if veryHighRangeMgdl.contains(val) {
            return .red
        } else {
            return .gray
        }
    }
}
