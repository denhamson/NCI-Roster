//
//  main.swift
//  NCI-Roster
//
//  Created by Mike Brown on 05/07/2017.
//
//

import Foundation

import Kitura
import KituraMustache
import KituraStencil
import KituraSession
import SwiftyJSON

import RealmSwift

// Where we will store the current session data
//var sess: SessionState?

// Initialising our KituraSession
let session = Session(secret: "kitura_session")


// Create a new router
let router = Router()
router.add(templateEngine: MustacheTemplateEngine())
router.add(templateEngine: StencilTemplateEngine())
router.viewsPath = "../../../Views/"
    
router.all(middleware: session)
router.all(middleware: BodyParser())

var sess: SessionState?

//Handle HTTP GET requests for Watchkeepers

router.get("/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        if let sess = sess, let userId = sess["userId"].string {
            try response.render("index.mustache", context: NCIStation.indexContext(userId: userId)).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

router.post("/login/") {
    request, response, next in
    let realm = try Realm()
    if realm.isEmpty {
        try NCIWatchKeeper.populate()
    }
    sess = request.session
    var maybeEmail: String?
    var maybeToken: String?
    switch request.body {
    case .urlEncoded(let params)?:
        maybeEmail = params["email"]?.removingPercentEncoding
        maybeToken = params["token"]?.removingPercentEncoding
    case .json(let params)?:
        maybeEmail = params["email"].string?.removingPercentEncoding
        maybeToken = params["token"].string?.removingPercentEncoding
    default: break
    }
    if let email = maybeEmail, let token = maybeToken, let sess = sess {
        if let user = realm.objects(NCIWatchKeeper.self).filter("emailAddress == %@ and password == %@", email, token).first {
            sess["userId"] = JSON(user.uuid)
            sess["admin"] = JSON(user.role.rawValue)
            try response.send("done").end()
        } else {
            try response.send("Unknown email").end()
        }
    } else {
        try response.send("Access Denied").end()
    }
}

router.get("/logout/") {
    request, response, next in
    
    sess = request.session
        sess?.destroy() {
            (error: NSError?) in
            if let error = error {
                response.send("Logout error! \(error.localizedDescription)")
            }
        }
        try response.render("login.stencil", context: ["routing":"/"]).end()
}

router.get("/help/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        if let sess = sess, let admin = sess["admin"].int {
            try response.render("help.mustache", context: [ "admin": admin ] ).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/help/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

router.get("/watchkeepers/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        if let sess = sess, let userId = sess["userId"].string {
            try response.render("watchkeepers.mustache", context: NCIWatchKeeper.watchKeepersContext(userId)).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/watchkeepers/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

router.get("/watchkeeper/:keeperId/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        if let sess = sess, let userId = sess["userId"].string, let keeperId = request.parameters["keeperId"] {
            try response.render("watchkeeper.mustache", context: NCIWatchKeeper.watchKeeperContext(keeperId)).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/watchkeeper/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

router.get("/profile/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        if let sess = sess, let userId = sess["userId"].string {
            try response.render("profile.mustache", context: NCIWatchKeeper.watchKeeperContext(userId)).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/profile/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

router.post("/watchkeeper/append/:name/:role/:email?/:token?/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        let realm = try Realm()
        if let sess = sess, let userId = sess["userId"].string, let user = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", userId).first {
            if let name = request.parameters["name"], let role = Int(request.parameters["role"]!) {
                let email = request.parameters["email"] ?? ""
                let token = request.parameters["token"] ?? ""
                let keeper = try NCIWatchKeeper.watchKeeperCreate(station: user.station!, name:name, email: email, role: role, token: token)
                try response.render("watchkeeper.mustache", context: NCIWatchKeeper.watchKeeperContext(keeper.uuid)).end()
            } else {
                response.send("unplanned error on append")
            }
        } else {
            try response.render("login.stencil", context: ["routing":"/watchkeeper/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

router.post("/watchkeeper/:keeperId/:name/:role/:email?/:token?/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        if let sess = sess, let userId = sess["userId"].string, let keeperId = request.parameters["keeperId"] {
            if let name = request.parameters["name"],  let role = Int(request.parameters["role"]!) {
                let email = request.parameters["email"] ?? ""
                let token = request.parameters["token"] ?? ""
                try NCIWatchKeeper.watchKeeperUpdate(watcherId: keeperId, name:name, email: email, role: role, token: token)
            }
            try response.render("watchkeeper.mustache", context: NCIWatchKeeper.watchKeeperContext(keeperId)).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/watchkeeper/"]).end()
        }
    } catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

//Handle HTTP GET requests for Roster
router.get("/rosters/:siteSelected?/:monthSelected?/") {
    request, response, next in
    defer { next() }
    do {
        sess = request.session
        let realm = try Realm()
        let siteSelected = request.parameters["siteSelected"] ?? ""
        let monthSelected = request.parameters["monthSelected"] ?? ""
        let calendar = Calendar.current
        if let sess = sess, let userId = sess["userId"].string {
            let user = realm.objects(NCIWatchKeeper.self).filter("uuid == %@", userId).first!
            let site = siteSelected == "" ? user.station!.sites.first! : realm.objects(NCISite.self).filter("uuid = %@", siteSelected, user.station!).first!
            let monthBeginning = monthSelected == "" ? DateComponents.init(calendar: calendar, year: calendar.component(.year, from: Date()), month: calendar.component(.month, from: Date()), day: 1).date : Date(timeIntervalSinceReferenceDate: Double(monthSelected)!)
            try response.render("rosters.stencil", context: NCIRoster.rostersContext(watchKeeper: user, site: site, monthBeginning: monthBeginning!)).end()
        } else {
            try response.render("login.stencil", context: ["routing":"/rosters/" + (siteSelected == "" ? "" : siteSelected + "/") + (monthSelected == "" ? "" : monthSelected + "/") ] ).end()
        }
    }
    catch {
        response.send("Untrapped Error! \(error.localizedDescription)")
    }
}

//Handle HTTP GET requests for Roster Clearing
router.get("/roster/:rosterId/:keeperId?/:type?/:action?") {
    request, response, next in
    defer { next() }
    do {
        if let rosterId = request.parameters["rosterId"], let keeperId = request.parameters["keeperId"], let type = request.parameters["type"], let action = request.parameters["action"] {
            try NCIRoster.updateRoster(rosterId: rosterId, keeperId: keeperId, type: type, action: action)
        }
        let sess = request.session
        if let sess = sess, let userId = sess["userId"].string, let rosterId = request.parameters["rosterId"] {
            try response.render("roster.mustache", context: NCIRoster.rosterContext(userId: userId, rosterId: rosterId)).end()
        } else {
            try response.send("Access Denied").end()
        }
    }
    catch {
        response.send("Unexpected Result! \(error.localizedDescription)")
    }
}

//Handle HTTP GET requests for Roster Takers
router.post("/roster/take/") {
    request, response, next in
    defer { next() }
    let token = request.queryParameters["token"] ?? ""
    let option = request.queryParameters["option"] ?? ""
    response.send("alert('Take selected for "+option+" @ "+token+"');")
}

