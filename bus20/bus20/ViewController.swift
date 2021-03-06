//
//  ViewController.swift
//  bus20
//
//  Created by SATOSHI NAKAJIMA on 8/27/18.
//  Copyright © 2018 SATOSHI NAKAJIMA. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    struct ScheduledRider {
        let rider:Rider
        let rideTime:CGFloat
        init(graph:Graph, limit:CGFloat) {
            rider = Rider(graph:graph)
            rideTime = CGFloat(Random.float(Double(limit)))
        }
    }
    
    @IBOutlet var viewMain:UIView!
    @IBOutlet var label:UILabel!
    let graph = Graph(w: Metrics.graphWidth, h: Metrics.graphHeight, unit: Metrics.edgeLength)
    let labelTime = UILabel(frame: .zero) // to render text
    var routeView:UIImageView!
    var scale = CGFloat(1.0)
    var shuttles = [Shuttle]()
    var start = Date()
    var riders = [Rider]()
    var speedMultiple = Metrics.speedMultiple
    var scheduled = [ScheduledRider]()
    var done = false
    var totalCount:CGFloat = 0
    var busyCount:CGFloat = 0
    var totalOccupancy:CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        let frame = view.frame
        let mapView = UIImageView(frame: frame)
        scale = min(frame.size.width / CGFloat(Metrics.graphWidth + 1),
                        frame.size.height / CGFloat(Metrics.graphHeight+1)) / Metrics.edgeLength
        UIGraphicsBeginImageContextWithOptions(frame.size, true, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()!
        graph.render(ctx:ctx, frame: frame, scale:scale)
        mapView.image = UIGraphicsGetImageFromCurrentImageContext()

        viewMain.addSubview(mapView)

        routeView = UIImageView(frame:frame)
        viewMain.addSubview(routeView)
        
        Random.seed(0)
        start(count: Metrics.numberOfShuttles)
    }
    
    func start(count:Int) {
        done = false
        speedMultiple = Metrics.speedMultiple
        Rider.resetId()
        label.text = ""
        totalCount = 0
        busyCount = 0
        totalOccupancy = 0
        start = Date()
        riders = [Rider]()
        scheduled = [ScheduledRider]()
        shuttles = (0..<count).map { Shuttle(hue: 1.0/CGFloat(count) * CGFloat($0), graph:graph) }
        update()
    }
    
    func update() {
        let time = CGFloat(Date().timeIntervalSince(start)) * speedMultiple
        
        while let rider = scheduled.first, rider.rideTime < time {
            scheduled.removeFirst()
            rider.rider.startTime = time
            assign(rider: rider.rider)
        }
        
        UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()!

        labelTime.text = String(format: "%2d:%02d", Int(time / 60), Int(time) % 60)
        labelTime.drawText(in: CGRect(x: 2, y: 2, width: 100, height: 20))
        shuttles.forEach() {
            $0.update(graph:graph, time:time)
            $0.render(ctx: ctx, graph: graph, scale: scale, time:time)
            
            // Exclude the beginning and tail end from the Shuttle stats
            if time > Metrics.playDuration / 3 && time < Metrics.playDuration {
                totalCount += 1
                totalOccupancy += $0.ocupancy
                if $0.isBusy { busyCount += 1 }
            }
        }
        
        let activeRiders = riders.filter({ $0.state != .done })
        activeRiders.forEach() {
            $0.render(ctx: ctx, graph: graph, scale: scale)
        }
        if done == false && riders.count > 0 && activeRiders.count == 0 {
            done = true
            postProcess()
        }
        
        routeView.image = UIGraphicsGetImageFromCurrentImageContext()!
        
        DispatchQueue.main.async {
            self.update()
        }
    }
    
    func postProcess() {
        let count = CGFloat(riders.count)
        let wait = riders.reduce(CGFloat(0.0)) { $0 + $1.pickupTime - $1.startTime }
        let ride = riders.reduce(CGFloat(0.0)) { $0 + $1.dropTime - $1.pickupTime }
        let extra = riders.reduce(CGFloat(0.0)) { $0 + $1.dropTime - $1.pickupTime - $1.route.length }
        print(String(format: "w:%.1f, r:%.1f, e:%.1f, u:%.1f%%, o:%.1f%%",
                     wait/count, ride/count, extra/count,
                     busyCount * 100 / totalCount, totalOccupancy * 100 / totalCount ))
        label.text = String(format: "Number of Shuttles: %d\nShuttle Capacity: %d\nPassengers/Hour: %d\nAvarage Wait: %.1f min\nAvarage Ride: %.1f min\nAverage Detour: %.1f min\nShuttle Utilization: %.1f%%\nOccupancy Rate: %.1f%%",
                            Metrics.numberOfShuttles, Metrics.shuttleCapacity, Metrics.riderCount,
                                wait/count, ride/count, extra/count,
                                busyCount * 100 / totalCount, totalOccupancy * 100 / totalCount )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func add(_ sender:UIBarButtonItem) {
        addRider()
    }
    
    func addRider() {
        let rider = Rider(graph:graph)
        assign(rider: rider)
    }
    
    @IBAction func test(_ sender:UIBarButtonItem) {
        Random.nextSeed() // 4, 40, 110
        print("Seed=", Random.seed)
        
        start(count: 1)
        addRider()
        addRider()
        addRider()
        addRider()
        addRider()
        addRider()
        let frame = view.frame
        UIGraphicsBeginImageContextWithOptions(frame.size, true, 0.0)
        defer { UIGraphicsEndImageContext() }
        let ctx = UIGraphicsGetCurrentContext()!
        graph.render(ctx:ctx, frame: frame, scale:scale)
        shuttles.forEach() {
            $0.render(ctx: ctx, graph: graph, scale: scale, time:0)
        }
        
        riders.forEach() {
            $0.render(ctx: ctx, graph: graph, scale: scale)
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let path = documents[0].appendingPathComponent("bus20.png")
        let data = UIImagePNGRepresentation(image)!
        try! data.write(to: path)
        print(path)
        
        print(shuttles[0])
    }
    
    @IBAction func emulate(_ sender:UIBarButtonItem) {
        Random.seed(0)
        
        start(count: Metrics.numberOfShuttles)
        scheduled = Array(0..<Metrics.riderCount * Int(Metrics.playDuration / 60)).map({ (_) -> ScheduledRider in
            return ScheduledRider(graph:graph, limit:Metrics.playDuration)
        }).sorted { $0.rideTime < $1.rideTime }
        /*
        scheduled.forEach {
            print($0.rideTime)
            riders.append($0.rider)
            assign(rider: $0.rider)
        }
        */
    }
    
    func assign(rider:Rider) {
        riders.append(rider)
        let before = Date()
        let bestPlan = Shuttle.bestPlan(shuttles: shuttles, graph: graph, rider: rider)
        let delta = Date().timeIntervalSince(before)
        let maxDepth = shuttles.reduce(0) { max($0, $1.depth) }
        print(String(format:"bestPlan:%.0f, time:%.4f, riders:%d, depth:%d", bestPlan.cost, delta, riders.count, maxDepth))
        bestPlan.shuttle.adapt(routes:bestPlan.routes, rider:rider)
        if delta > 0.5 {
            done = true
            scheduled.removeAll()
            label.text = "This setting is too complext for this device to process."
        }
        
        // Debug only
        //bestPlan.shuttle.debugDump()
    }
}

