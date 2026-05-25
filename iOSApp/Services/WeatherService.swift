import Foundation
import CoreLocation

@Observable
final class WeatherService: NSObject, CLLocationManagerDelegate {
    var temperature: Double? = nil
    var highTemp: Double? = nil
    var lowTemp: Double? = nil
    var weatherCode: Int? = nil
    var isLoading = false
    var denied = false

    private let manager = CLLocationManager()
    private var didFetch = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        guard !didFetch else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLoading = true
            manager.requestLocation()
        default:
            denied = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isLoading = true
            manager.requestLocation()
        case .denied, .restricted:
            denied = true
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }

    private func fetchWeather(lat: Double, lon: Double) {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1&temperature_unit=fahrenheit"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.didFetch = true
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current"] as? [String: Any],
                      let daily   = json["daily"]   as? [String: Any] else { return }
                self?.temperature  = current["temperature_2m"] as? Double
                self?.weatherCode  = current["weather_code"]  as? Int
                self?.highTemp = (daily["temperature_2m_max"] as? [Double])?.first
                self?.lowTemp  = (daily["temperature_2m_min"] as? [Double])?.first
            }
        }.resume()
    }

    var icon: String {
        switch weatherCode ?? -1 {
        case 0:        return "sun.max.fill"
        case 1:        return "sun.max.fill"
        case 2:        return "cloud.sun.fill"
        case 3:        return "cloud.fill"
        case 45, 48:   return "cloud.fog.fill"
        case 51...57:  return "cloud.drizzle.fill"
        case 61...67:  return "cloud.rain.fill"
        case 71...77:  return "cloud.snow.fill"
        case 80...82:  return "cloud.heavyrain.fill"
        case 85, 86:   return "cloud.snow.fill"
        case 95...99:  return "cloud.bolt.rain.fill"
        default:       return "cloud.fill"
        }
    }

    var condition: String {
        switch weatherCode ?? -1 {
        case 0:        return "Clear"
        case 1:        return "Mostly clear"
        case 2:        return "Partly cloudy"
        case 3:        return "Overcast"
        case 45, 48:   return "Foggy"
        case 51...57:  return "Drizzle"
        case 61...67:  return "Rain"
        case 71...77:  return "Snow"
        case 80...82:  return "Showers"
        case 85, 86:   return "Snow showers"
        case 95...99:  return "Thunderstorm"
        default:       return "Cloudy"
        }
    }

    func formatted(_ temp: Double) -> String { "\(Int(temp.rounded()))°F" }
}
