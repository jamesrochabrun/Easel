//
//  PortAllocatorTests.swift
//  EaselServerManagerTests
//

@testable import EaselServerManager
import Testing

@Suite
struct PortAllocatorTests {

  @Test
  func assignsBasePortForFirstProject() {
    let port = PortAllocator.assignPort(
      for: "/projects/first",
      existingAssignments: [:]
    )
    #expect(port == PortAllocator.basePort)
  }

  @Test
  func reusesExistingAssignment() {
    let assignments: [String: UInt16] = ["/projects/myapp": 8085]
    let port = PortAllocator.assignPort(
      for: "/projects/myapp",
      existingAssignments: assignments
    )
    #expect(port == 8085)
  }

  @Test
  func incrementsPortForNewProject() {
    let assignments: [String: UInt16] = ["/projects/first": 8080]
    let port = PortAllocator.assignPort(
      for: "/projects/second",
      existingAssignments: assignments
    )
    #expect(port == 8081)
  }

  @Test
  func fillsGapWhenPortFreed() {
    // Ports 8080 and 8082 are taken, 8081 is free
    let assignments: [String: UInt16] = [
      "/projects/a": 8080,
      "/projects/c": 8082,
    ]
    let port = PortAllocator.assignPort(
      for: "/projects/b",
      existingAssignments: assignments
    )
    #expect(port == 8081)
  }

  @Test
  func assignsSequentialPortsForMultipleProjects() {
    var assignments: [String: UInt16] = [:]
    let dirs = (0..<5).map { "/projects/project\($0)" }

    for dir in dirs {
      let port = PortAllocator.assignPort(
        for: dir,
        existingAssignments: assignments
      )
      assignments[dir] = port
    }

    let ports = Array(assignments.values).sorted()
    #expect(ports == [8080, 8081, 8082, 8083, 8084])
  }

  @Test
  func allPortsAreUnique() {
    var assignments: [String: UInt16] = [:]
    for i in 0..<20 {
      let dir = "/projects/project\(i)"
      let port = PortAllocator.assignPort(
        for: dir,
        existingAssignments: assignments
      )
      assignments[dir] = port
    }

    let uniquePorts = Set(assignments.values)
    #expect(uniquePorts.count == 20)
  }

  @Test
  func removeAssignmentFreesPort() {
    var assignments: [String: UInt16] = [
      "/projects/a": 8080,
      "/projects/b": 8081,
    ]

    PortAllocator.removeAssignment(
      for: "/projects/a",
      from: &assignments
    )

    #expect(assignments["/projects/a"] == nil)
    #expect(assignments["/projects/b"] == 8081)

    // New project should get the freed port
    let port = PortAllocator.assignPort(
      for: "/projects/c",
      existingAssignments: assignments
    )
    #expect(port == 8080)
  }
}
