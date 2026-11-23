import Testing
@testable import VexFoundation

// VexFlow 5.9.0 cases. The drawing code is in `Upstream59Scenes`; the asserts are in `Upstream59NotationTests`.
extension UpstreamSVGParityTests {
    @Test("GermanLuteNote.Principal_courses_on_one_staffless_row")
    func germanLuteNotePrincipalCoursesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "GermanLuteNote", test: "Principal_courses_on_one_staffless_row", width: 470, height: 150
        ) { factory, context in
            _ = try Upstream59Scenes.germanPrincipalCourses(factory, context)
        }
    }
}
