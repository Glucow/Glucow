import SwiftUI
import Charts

struct GlucoseChartMMOLView: View {
    let dataPoints: [(date: Date, value: Double)]
    
    // Boundaries (mmol if useMmol == true, mg/dL if false)
    let veryLowRange: ClosedRange<Double>
    let lowRange: ClosedRange<Double>
    let inRange: ClosedRange<Double>
    let highRange: ClosedRange<Double>
    let veryHighRange: ClosedRange<Double>

    var body: some View {
        let points = dataPoints // Use a single converted dataset for consistency
        
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
            boundaryRule("Low",       fixedLowLine(),     .yellow)
            boundaryRule("In Range",  fixedRangeLine(),      .green)
            boundaryRule("High",      fixedHighLine(),    .yellow)
            boundaryRule("Fixed Top", fixedTopLine(), .red)
            boundaryRule("Fixed Bottom", fixedBottomLine(), .red)
            
            let domainTop = yDomain().upperBound
            
            if domainTop >= 18.0 {
                boundaryRule("V High", fixedVeryHighLine(), .red)
            }
            
            if domainTop >= 21.0 {
                boundaryRule("V High", fixedVeryVeryHighLine(), .red)
            }
            if domainTop >= 28.0 {
                boundaryRule("Max High", fixedMaxHighLine(), .red)
            }
            
            RuleMark(x: .value("Right Edge", xDomain().upperBound.addingTimeInterval(75)))
                .lineStyle(StrokeStyle(lineWidth: 1.3))
                .foregroundStyle(.gray)
                .offset(y: -4.5)
            
            RuleMark(y: .value("Bottom Edge", 2.2))
                .lineStyle(StrokeStyle(lineWidth: 1.3))
                .foregroundStyle(.gray)
            
            let connectingLineData = [
                    (date: xDomain().upperBound, value: 2.2), // Start of the line
                    (date: xDomain().upperBound.addingTimeInterval(75), value: 2.2) // End of the line
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
        
        let lower = max(0.0, min(dataMin, 2.0)) // Ensure a uniform floor at 0.0 or 2.0
        
        let top: Double
            if dataMax > 21.0 {
                top = 27.0
            } else if dataMax > 18.0 {
                top = 21.0
            } else if dataMax > 15.0 {
                top = 18.0
            } else {
                top = 15.0
            }
        return lower ... max(top, dataMax)
    }

    // A fixed top line at 15 mmol
    private func fixedTopLine() -> Double {
        return 15.0
    }
    
    private func fixedBottomLine() -> Double {
        return 2.2
    }
    
    private func fixedMaxHighLine() -> Double {
        return 28
    }
    
    private func fixedVeryVeryHighLine() -> Double {
        return 21
    }
    
    private func fixedVeryHighLine() -> Double {
        return 18
    }
    
    private func fixedHighLine() -> Double {
        return 13
    }
    
    private func fixedRangeLine() -> Double {
        return 8.5
    }
    
    private func fixedLowLine() -> Double {
        return 3.9
    }
    
    private func fixedVeryLowLine() -> Double {
        return 2.8
    }

    // MARK: - boundaryRule
    @ChartContentBuilder
    private func boundaryRule(_ title: String, _ val: Double, _ color: Color) -> some ChartContent {
        RuleMark(y: .value(title, val))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(color.opacity(0.8))
            .annotation(position: .trailing) {
                Text(String(format: "%.1f", val))
                    .font(.caption2)
                    .foregroundColor(color)
                    .padding(.horizontal, 4)
            }
    }

    // MARK: - colorForValue
    private func colorForValue(_ val: Double) -> Color {
        if veryLowRange.contains(val) {
            return .red
        } else if lowRange.contains(val) {
            return .yellow
        } else if inRange.contains(val) {
            return .green
        } else if highRange.contains(val) {
            return .yellow
        } else if veryHighRange.contains(val) {
            return .red
        } else {
            return .gray
        }
    }
}

