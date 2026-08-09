import Foundation

enum PlantExpertContext {
    /// Compact specimen snapshot for the Plant Expert system prompt (~1–2KB).
    static func build(plant: Plant, careGuide: CareGuide?) -> String {
        var lines: [String] = []
        lines.append("nickname: \(plant.nickname)")
        if let common = plant.speciesCommonName, !common.isEmpty {
            lines.append("common_name: \(common)")
        }
        if let latin = plant.speciesLatinName, !latin.isEmpty {
            lines.append("latin_name: \(latin)")
        }
        if let family = plant.family, !family.isEmpty {
            lines.append("family: \(family)")
        }
        lines.append("placement: \(plant.placement.label)")
        if let score = plant.healthScore {
            lines.append("health_score: \(score)/100 (\(plant.healthStatus.rawValue))")
        }
        if let interval = plant.wateringIntervalDays {
            lines.append("watering_interval_days: \(interval)")
        }
        if let ml = plant.wateringAmountMl {
            lines.append("watering_amount: \(UnitsFormatting.waterAmount(ml: ml))")
        }
        if let next = plant.nextWateringDate, !next.isEmpty {
            lines.append("next_watering: \(next)")
        }
        lines.append("added: \(plant.addedDate)")
        lines.append("home_region: \(UnitsFormatting.homeRegion)")

        if let guide = careGuide {
            lines.append("care_guide:")
            if let light = guide.lightRequirement { lines.append("- light: \(light)") }
            if let freq = guide.wateringFrequency { lines.append("- watering_frequency: \(freq)") }
            if let amount = guide.wateringAmount {
                lines.append("- watering_amount_guide: \(UnitsFormatting.waterAmount(label: amount))")
            }
            if let soil = guide.soilMix { lines.append("- soil: \(soil)") }
            if let temp = guide.temperatureRange { lines.append("- temperature: \(temp)") }
            if let humidity = guide.humidityRange { lines.append("- humidity: \(humidity)") }
            if let difficulty = guide.difficultyLevel {
                lines.append("- difficulty: \(difficulty)/5")
            }
        }

        let text = lines.joined(separator: "\n")
        if text.count <= 2000 { return text }
        return String(text.prefix(2000))
    }
}
