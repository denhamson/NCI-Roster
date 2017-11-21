//
//  Watch.swift
//  NCI-Roster
//
//  Created by Mike Brown on 07/07/2017.
//
//

import Foundation
import RealmSwift

//let realm = try! Realm()

public class NCI {
    public static var calendar: Calendar { return Calendar.current }
}
public class NCIStation: Object {
    @objc dynamic var name: String = "NCI Mundesley"
    @objc dynamic var uuid = UUID().uuidString
    @objc dynamic var eMailDomain: String = "nci-mundesley.org.uk"
    let watchKeepers = LinkingObjects(fromType: NCIWatchKeeper.self, property: "station")
    let sites = LinkingObjects(fromType: NCISite.self, property: "station")

    override public static func primaryKey() -> String? {
        return "uuid"
    }

    convenience init(name: String) {
        self.init()
        self.name = name
    }

    public static func indexContext(userId: String) throws -> [ String:Any ]  {
        let realm = try Realm()
        let user = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", userId).first!
        return [
            "station": user.station?.name as Any,
            "name": user.name,
            "manager": user.role == NCIWatchKeeperRole.RosterAdmin ? 1 : 0,
            "userId": user.uuid,
            "sites": try user.station!.sitesContext(),
            "months": try months(),
        ]
    }

    private func sitesContext() throws -> [Any] {
        var sitelist: [Any] = []
        for site in sites {
            sitelist.append( [ "uuid": site.uuid, "name": site.name, "selected": site == sites.first! ? "selected" : "" ] )
        }
        return sitelist
    }
    
    private static func months() throws -> [ Any ] {
        let calendar = Calendar.current
        let monthBeginning = DateComponents.init(calendar: calendar, year: calendar.component(.year, from: Date()), month: calendar.component(.month, from: Date()), day: 1).date!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM YYYY"
        let currentMonth = DateComponents.init(calendar: NCI.calendar, year: NCI.calendar.component(.year, from: Date()), month: NCI.calendar.component(.month, from: Date()), day: 1).date!
        var months: [Any] = []
        for diff in 0...12 {
            let date = NCI.calendar.date(byAdding: .month, value: diff, to: currentMonth)!
            let format = formatter.string(from: date)
            let key = String(date.timeIntervalSinceReferenceDate)
            months.append([ "key": key, "value": format, "selected": date == monthBeginning ? "selected" : "" ])
        }
        return months
    }
    
}

public class NCISite: Object {
    @objc dynamic var station: NCIStation?
    @objc dynamic var name: String = ""
    @objc dynamic var uuid = UUID().uuidString
    let watches = LinkingObjects(fromType: NCIWatch.self, property: "site")
    @objc dynamic var shortName: String { return name.replacingOccurrences(of: " ", with: "").lowercased() }
    override public static func primaryKey() -> String? {
        return "uuid"
    }
    convenience init(name: String, station: NCIStation) {
        self.init()
        self.name = name
        self.station = station
    }
}

public enum NCIWatchType: Int {
    case allYear
    case summerOnly
    case winterOnly
}

public class NCIWatch: Object {
    @objc dynamic var site : NCISite?
    //dynamic var baseWatch : NCIWatch?
    @objc dynamic var day: Int = 0
    @objc dynamic var hour: Int = 0
    @objc dynamic var uuid = UUID().uuidString
    @objc private dynamic var privateType = NCIWatchType.allYear.rawValue
    var type: NCIWatchType { get { return NCIWatchType(rawValue: privateType)! } set { privateType = newValue.rawValue} }
    let watchKeepers = List<NCIWatchKeeper>()
    let rosters = LinkingObjects(fromType: NCIRoster.self, property: "watch")

    override public static func primaryKey() -> String? {
        return "uuid"
    }

    convenience init(site: NCISite, day: Int, hour: Int) {
        self.init()
        self.site = site
        self.day = day
        self.hour = hour
    }
    
}

public enum NCIWatchKeeperRole: Int {
    case User
    case RosterAdmin
}

public class NCIWatchKeeper: Object {
    @objc dynamic var name = ""
    @objc dynamic var emailAddress = ""
    @objc dynamic var password = "ncipass!"
    @objc dynamic var uuid = UUID().uuidString
    @objc dynamic var station : NCIStation?
    @objc private dynamic var privateRole = NCIWatchKeeperRole.User.rawValue
    var role: NCIWatchKeeperRole { get { return NCIWatchKeeperRole(rawValue: privateRole)! } set { privateRole = newValue.rawValue} }
    var lastName: String { return name.components(separatedBy: " ").last ?? name.components(separatedBy: ".").last ?? name }
    var firstNames: String { return name.components(separatedBy: lastName).first ?? ""  }
    var sortedName: String { return lastName+", "+firstNames }
    let rosters = LinkingObjects(fromType: NCIRoster.self, property: "watchKeepers")
    let watches = LinkingObjects(fromType: NCIWatch.self, property: "watchKeepers")

    override public static func primaryKey() -> String? {
        return "uuid"
    }
    convenience init(name: String, station: NCIStation) {
        self.init()
        self.name = name
        self.station = station
        self.emailAddress=name.replacingOccurrences(of: " ", with: ".").lowercased()+"@"+(self.station?.eMailDomain)!
    }
    
    enum NCIWatchKeeperError: Error {
        case unknownUUID
    }
    
    public static func watchKeepersContext(_ userId: String) throws -> [ String:Any ]  {
        let realm = try! Realm()
        let watchers = realm.objects(NCIWatchKeeper.self)
        var dictionary = [String:String]()
        var names = [Any]()
        for watcher in watchers {
            dictionary.updateValue(watcher.uuid, forKey: watcher.sortedName)
        }
        for item in dictionary.sorted(by: { $0.0 < $1.0 }) {
            names.append([ "uuid": item.value, "name": item.key ])
        }
        return [ "count": watchers.count, "watchers": names ]
    }
    
    public static func watchKeeperContext(_ watcherId: String) throws -> [ String:Any ]  {
        let realm = try! Realm()
        if watcherId == "append" {
            return [ "uuid": "append", "name": "", "emailAddress": "", "selectedRole": 0, "roles": [ [ "role":"User", "selected": "selected", "value": 0 ] , ["role": "Roster Administrator", "selected": "", "value": 1 ] ] ]
        }
        if let watcher = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", watcherId).first {
            return [ "uuid": watcher.uuid, "name": watcher.name, "emailAddress": watcher.emailAddress, "selectedRole": watcher.privateRole, "roles": [ [ "role":"User", "selected": watcher.privateRole == 0 ? "selected" : "", "value": 0 ] , ["role": "Roster Administrator", "selected": watcher.privateRole == 1 ? "selected" : "", "value": 1 ] ] ]
        } else {
            throw NCIWatchKeeperError.unknownUUID
        }
    }
    
    public static func watchKeeperUpdate(watcherId: String, name: String, email:String, role:Int, token:String) throws -> Void  {
        let realm = try Realm()
        if let watcher = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", watcherId).first {
            try realm.write {
                watcher.name = name
                watcher.emailAddress = email
                watcher.privateRole = role
                if token != "" { watcher.password = token }
                realm.add(watcher, update: true)
            }
        } else {
            throw NCIWatchKeeperError.unknownUUID
        }
    }
    
    public static func watchKeeperCreate(station: NCIStation, name: String, email:String, role:Int, token:String) throws -> NCIWatchKeeper  {
        let realm = try Realm()
        let watcher = NCIWatchKeeper(name: name, station: station)
            watcher.emailAddress = email
            watcher.privateRole = role
        if token != "" { watcher.password = token }
        try realm.write {
            realm.add(watcher)
        }
        return watcher
    }

    public static func populate() throws -> Void {
        let realm = try! Realm()
        try! realm.write {
            realm.deleteAll()
        }
        if realm.objects(NCIWatchKeeper.self).count == 0 {
            let defaultStation="Mundesley"
            let defaultSites=["Beach Road","Vale Road"]
            let defaultWatchers = ["Mike Brown", "Philip Coe", "Richard Ridgewell", "Peter Molyneux", "Duncan Mackenzie", "Paul Simpson", "John Allen"]
            var sites = [NCISite]()
            try! realm.write {
                let station = NCIStation(name: defaultStation)
                realm.add(station)
                for name in defaultSites {
                    let site = NCISite(name: name, station: station)
                    realm.add(site)
                    sites.append(site)
                }
                for name in defaultWatchers {
                    let watcher = NCIWatchKeeper(name: name, station: station)
                    realm.add(watcher)
                }
                for day in 1...7 {
                    for hour in 8...16 {
                        switch hour {
                        case 8,10,12,14,16 :
                            let watch = NCIWatch(site: sites[0], day: day, hour: hour)
                            watch.type = hour == 16 ? NCIWatchType.summerOnly : NCIWatchType.allYear
                            realm.add(watch)
                        default :
                            let watch = NCIWatch(site: sites[1], day: day, hour: hour)
                            watch.type = NCIWatchType.summerOnly
                            realm.add(watch)
                        }
                    }
                }
                /*
                defaultWatchers.append("Vacant Watch")
                for watch in realm.objects(NCIWatch.self) {
                    for _ in 0...1 {
                        if let watchKeeper = realm.objects(NCIWatchKeeper.self).filter("name = %@", defaultWatchers[Int(arc4random_uniform(UInt32(defaultWatchers.count)))]).first {
                            watch.watchKeepers.append(watchKeeper)
                        }
                    }
                    realm.add(watch, update: true)
                }
                */
            }
        }
    }
}


public class NCIRoster: Object {
    @objc dynamic var watch: NCIWatch?
    @objc dynamic var time: Date = Date()
    @objc dynamic var uuid = UUID().uuidString
    let watchKeepers = List<NCIWatchKeeper>()
    @objc dynamic var timeString: String { return time.description(with: Locale.current) }
    
    override public static func primaryKey() -> String? {
        return "uuid"
    }
    
    convenience init(watch: NCIWatch, time: Date) {
        self.init()
        self.watch = watch
        self.time = time
        for watchKeeper in watch.watchKeepers {
            self.watchKeepers.append(watchKeeper)
        }
    }
    
    public static func rostersContext(watchKeeper: NCIWatchKeeper, site: NCISite, monthBeginning: Date ) throws -> [ String:Any ]  {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM YYYY"
        return [
            "watcherId": watchKeeper.name,
            "watcher": watchKeeper.uuid,
            "siteSelected": site.name,
            "site": site.uuid,
            "month": String(monthBeginning.timeIntervalSinceReferenceDate),
            "monthSelected":formatter.string(from: monthBeginning),
            //"sites": try sites(site: site, station: watchKeeper.station!),
            //"months": try months(monthBeginning: monthBeginning),
            "watches": try watches(site: site, monthBeginning: monthBeginning),
            "days": try days(watchKeeper: watchKeeper, site: site, monthBeginning: monthBeginning)
        ]
    }
    
    public static func rosterContext(userId: String, rosterId: String) throws -> [ String:Any ]  {
        let realm = try Realm()
        let user = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", userId).first!
        let roster = realm.objects(NCIRoster.self).filter("uuid == %@", rosterId).first!
        // isManager, watchlist, filtered and available vars define who can be added to vacant watches
        var watchlist = realm.objects(NCIWatchKeeper.self).filter("station == %@", user.station!)
        if user.role == NCIWatchKeeperRole.User {
            watchlist = watchlist.filter("uuid == %@", user.uuid)
        }
        var keepers: [Any] = []
        for keeper in roster.watchKeepers {
            watchlist = watchlist.filter("uuid != %@", keeper.uuid)
            let regular = roster.watch!.watchKeepers.contains(keeper)
            keepers.append( [ "name": keeper.name, "uuid": keeper.uuid, "editable": user.role == NCIWatchKeeperRole.RosterAdmin || (user == keeper), "regular": regular ] )
        }
        var regulars: [Any] = []
        for regular in (roster.watch?.watchKeepers)! {
            watchlist = watchlist.filter("uuid != %@", regular.uuid)
            regulars.append( [ "name": regular.name, "uuid": regular.uuid, "editable": user.role == NCIWatchKeeperRole.RosterAdmin || (user == regular) ] )
        }
        var available: [Any] = []
        let complete = roster.watchKeepers.count > 1
        if !complete {
            var dictionary = [String:String]()
            for keeper in watchlist {
                dictionary.updateValue(keeper.uuid, forKey: keeper.sortedName)
            }
            for item in dictionary.sorted(by: { $0.0 < $1.0 }) {
                available.append([ "uuid": item.value, "name": item.key ])
            }
        }
        let calendar = Calendar.current
        let monthBeginning = DateComponents.init(calendar: calendar, year: calendar.component(.year, from: roster.time), month: calendar.component(.month, from: roster.time), day: 1).date!
        return [
            "roster": rosterId,
            "station": user.station!.name,
            "site": roster.watch!.site!.uuid,
            "month": String(monthBeginning.timeIntervalSinceReferenceDate),
            "isManager": user.role == NCIWatchKeeperRole.RosterAdmin,
            "user": user.name,
            "time": roster.timeString,
            "keepers": keepers,
            "regulars": regulars,
            "complete": complete,
            "available": available
        ]
    }
    
    public static func updateRoster(rosterId: String, keeperId: String, type: String, action: String) throws -> Void {
        enum updateError: String, Error {
            case keeperAlreadyAssigned
            case watchAlreadyFull
            case cannotDeleteUnassignedWatchKeeper
            case unexpectedUpdateOptions
        }
        let realm = try Realm()
        let roster = realm.objects(NCIRoster.self).filter("uuid == %@", rosterId).first!
        let keeper = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", keeperId).first!
        let options = ( action, type )
        try realm.write {
            switch options {
            case ("Assign", "Regular"):
                guard roster.watchKeepers.count < 2, roster.watch!.watchKeepers.count < 2 else {
                    throw updateError.watchAlreadyFull
                }
                guard !roster.watchKeepers.contains(keeper), !roster.watch!.watchKeepers.contains(keeper) else {
                    throw updateError.keeperAlreadyAssigned
                }
                roster.watch!.watchKeepers.append(keeper)
                roster.watchKeepers.append(keeper)
                for futureRoster in realm.objects(NCIRoster.self).filter("time > %@ and watch.day == %@ and watch.hour == %@", roster.time, roster.watch!.day, roster.watch!.hour) {
                    if !futureRoster.watchKeepers.contains(keeper) {
                        futureRoster.watchKeepers.append(keeper)
                    }
                }
            case ("Assign", "AdHoc"):
                guard roster.watchKeepers.count < 2 else {
                    throw updateError.watchAlreadyFull
                }
                guard !roster.watchKeepers.contains(keeper), !roster.watch!.watchKeepers.contains(keeper) else {
                    throw updateError.keeperAlreadyAssigned
                }
                roster.watchKeepers.append(keeper)
            case ("Delete", "Regular"):
                guard let index1 = roster.watch!.watchKeepers.index(of: keeper), let index2 = roster.watchKeepers.index(of: keeper) else {
                    throw updateError.cannotDeleteUnassignedWatchKeeper
                }
                roster.watch!.watchKeepers.remove(at: index1)
                roster.watchKeepers.remove(at: index2)
                for futureRoster in realm.objects(NCIRoster.self).filter("time > %@ and watch.day == %@ and watch.hour == %@", roster.time, roster.watch!.day, roster.watch!.hour) {
                    if let index3 = futureRoster.watchKeepers.index(of: keeper) {
                        futureRoster.watchKeepers.remove(at: index3)
                    }
                }
             case ("Delete", "AdHoc"):
                guard let index1  = roster.watchKeepers.index(of: keeper) else {
                    throw updateError.cannotDeleteUnassignedWatchKeeper
                }
                roster.watchKeepers.remove(at: index1)
            default:
                throw updateError.unexpectedUpdateOptions
            }
        }
    }
    
    private static func watches(site: NCISite, monthBeginning: Date) throws -> [Any] {
        let range = NCI.calendar.range(of: .day, in: .month, for: monthBeginning)!
        let monthEnding = DateComponents.init(calendar: NCI.calendar, year: NCI.calendar.component(.year, from: monthBeginning), month: NCI.calendar.component(.month, from: monthBeginning), day: Int(range.upperBound)-1).date!
        let isSummer = TimeZone.current.isDaylightSavingTime(for: monthBeginning) || TimeZone.current.isDaylightSavingTime(for: monthEnding)
        let realm = try! Realm()
        let watchList = realm.objects(NCIWatch.self).filter("site = %@ and day = 1", site)
        var watches: [Any] = []
        for item in watchList {
            if item.type == .allYear || ( item.type == .summerOnly && isSummer ) || ( item.type == .winterOnly && !isSummer ) {
                watches.append([ "watch": String(item.hour) + " - " + String(item.hour+2) ])
            }
        }
        return watches
    }
    
    private static func days(watchKeeper: NCIWatchKeeper, site: NCISite, monthBeginning: Date) throws -> [Any] {
        let range = NCI.calendar.range(of: .day, in: .month, for: monthBeginning)!
        var days: [Any] = []
        var watches: [Any] = []
        let realm = try! Realm()
        for day in Int(range.lowerBound)..<Int(range.upperBound) {
            let date = NCI.calendar.date(bySetting: .day, value: day, of: monthBeginning)!
            let weekday = NCI.calendar.component(.weekday, from: date)
            let weekdayString = NCI.calendar.weekdaySymbols[weekday-1]
            var lastName = [String]()
            watches.removeAll()
            let isSummer = TimeZone.current.isDaylightSavingTime(for: date)
            let watchList = realm.objects(NCIWatch.self).filter("site = %@ and day = %@", site, weekday)
            for watch in watchList {
                let time = NCI.calendar.date(bySetting: .hour, value: watch.hour, of: date)!
                let roster = realm.objects(NCIRoster.self).filter("watch = %@ and time = %@", watch, time).first ?? NCIRoster(watch: watch, time: time)
                if roster.realm == nil {
                    try! realm.write {
                        realm.add(roster)
                    }
                }
                if watch.type == .allYear || ( watch.type == .summerOnly && isSummer ) || ( watch.type == .winterOnly && !isSummer ) {
                    var name = [String]()
                    var color = [String]()
                    for keeper in roster.watchKeepers {
                        name.append(keeper.name)
                        if (keeper == watchKeeper) && (time.timeIntervalSinceNow > 0) {
                            if watch.watchKeepers.contains(keeper)  {
                                color.append("gold")
                            } else {
                                color.append("yellow")
                            }
                        } else if watchKeeper.role == NCIWatchKeeperRole.RosterAdmin && (time.timeIntervalSinceNow > 0) {
                            if watch.watchKeepers.contains(keeper)  {
                                color.append("grey")
                            } else {
                                color.append("lime")
                            }
                        } else {
                                color.append("")
                        }
                    }
                    if name.isEmpty {
                        for _ in 1...2 {
                            name.append("&nbsp;")
                            color.append(time.timeIntervalSinceNow > 0 ? "red" : "")
                        }
                    } else if name.count < 2 {
                        name.append("&nbsp;")
                        color.append(time.timeIntervalSinceNow > 0 ? "orange" : "")
                    }
                    if name == lastName && color[1] == "orange" { color[1] = "blue" }
                    let regularWatchVacant = watch.watchKeepers.count == 2 ? "false" : "true"
                    watches.append([ "watch1": name[0], "class1":color[0], "watch2": name[1], "class2":color[1], "regularWatchVacant": regularWatchVacant, "rosterId": roster.uuid, "time": roster.timeString ])
                    lastName = name
                }
            }
            days.append([ "day": day, "weekday": weekdayString, "watches": watches])
        }
        return days
    }
}
