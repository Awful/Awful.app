//  IndexPersistence.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulScraping
import CoreData

extension IndexScrapeResult {

    @discardableResult func upsert(
        into context: NSManagedObjectContext
    ) throws -> UpsertResult {
        var rawGroups: [ScrapedForum] = []
        var rawForums: [(forum: ScrapedForum, depth: Int)] = []
        for (scraped, depth) in allForums {
            if scraped.hasThreads {
                rawForums.append((scraped, depth))
            } else {
                rawGroups.append(scraped)
            }
        }
        let unorderedGroups = UpsertBatch(
            in: context,
            identifiedBy: \ForumGroup.groupID,
            identifiers: rawGroups.map { $0.id })
        let unorderedForums = UpsertBatch(
            in: context,
            identifiedBy: \Forum.forumID,
            identifiers: rawForums.map { $0.forum.id })
        for (raw, i) in zip(rawGroups, Int32(0)...) {
            let group = unorderedGroups[raw.id]
            raw.update(group)
            if group.index != i { group.index = i }
        }
        for ((raw, _), i) in zip(rawForums, Int32(0)...) {
            let forum = unorderedForums[raw.id]
            raw.update(forum)
            if forum.index != i {
                let wasDelisted = forum.index < 0
                forum.index = i

                // The favorites list's fetched results controller observes ForumMetadata but leans
                // on Forum.index, so a forum the site has started listing again needs a change the
                // metadata controller can actually see.
                if wasDelisted { forum.metadata.tickleForFetchedResultsController() }
            }
        }
        let moderators = rawForums.flatMap { $0.forum.moderators }
        let unorderedUsers = UpsertBatch(
            in: context,
            identifiedBy: \User.userID,
            identifiers: moderators.map { $0.userID })
        for mod in moderators {
            let user = unorderedUsers[mod.userID]
            mod.update(user)
        }

        var currentGroup: ForumGroup?
        var forumStack: [Forum] = []
        for (scraped, depth) in allForums {
            if !scraped.hasThreads {
                currentGroup = unorderedGroups[scraped.id]
                continue
            }

            if depth == 0 {
                assertionFailure("depth = 0 is only for groups")
                continue
            }

            let depth = depth - 1
            if forumStack.count > depth {
                forumStack.removeSubrange(depth...)
            }

            let forum = unorderedForums[scraped.id]
            if forum.group != currentGroup { forum.group = currentGroup }

            if forum.parentForum != forumStack.last {
                forum.parentForum = forumStack.last
            }

            let shouldBeVisible: Bool
            if let parent = forumStack.last?.metadata {
                shouldBeVisible = parent.showsChildrenInForumList && parent.visibleInForumList
            } else {
                shouldBeVisible = true
            }
            if forum.metadata.visibleInForumList != shouldBeVisible {
                forum.metadata.visibleInForumList = shouldBeVisible

                // Pointless set triggers change in fetched results controller that observes only Forum objects.
                let index = forum.index
                forum.index = index
            }

            forumStack.append(forum)
        }

        // Forums come and go. Anything the site has stopped listing drops out of the forum list,
        // but we keep the row: threads, per-forum themes, and the favorite flag hang off it, and a
        // forum that reappears should come back with its favorite intact. A scrape with no forums
        // in it is nonsense (a mangled response, say) and acting on it would blank the whole list.
        if !rawForums.isEmpty {
            let scrapedForumIDs = rawForums.map { $0.forum.id }
            let delisted = Forum.fetch(in: context) {
                $0.predicate = .and(
                    .init("NOT (\(\Forum.forumID) IN \(scrapedForumIDs))"),
                    .or(.init("\(\Forum.index) >= 0"),
                        .init("\(\Forum.metadata.visibleInForumList) == YES")))
                $0.returnsObjectsAsFaults = false
            }
            for forum in delisted {
                if forum.metadata.visibleInForumList {
                    forum.metadata.visibleInForumList = false
                }

                // A negative index is how we say "the site isn't listing this right now". Setting
                // it unconditionally doubles as the pointless set that the Forum-observing fetched
                // results controller needs, and…
                forum.index = -1

                // …the favorites list observes ForumMetadata, so it needs its own nudge.
                forum.metadata.tickleForFetchedResultsController()
            }
        }

        if !rawGroups.isEmpty {
            let scrapedGroupIDs = rawGroups.map { $0.id }
            let delisted = ForumGroup.fetch(in: context) {
                $0.predicate = .and(
                    .init("NOT (\(\ForumGroup.groupID) IN \(scrapedGroupIDs))"),
                    .init("\(\ForumGroup.index) >= 0"))
            }
            for group in delisted {
                group.index = -1
            }
        }

        let profile = currentUser.upsert(into: context)

        return UpsertResult(currentUser: profile.user)
    }

    struct UpsertResult {
        let currentUser: User
    }
}

extension IndexScrapeResult.ScrapedForum {
    func update(_ group: ForumGroup) {
        if group.groupID != id { group.groupID = id }
        if group.name != title { group.name = title }
    }

    func update(_ forum: Forum) {
        if forum.forumID != id { forum.forumID = id }
        if forum.name != title {
            forum.name = title
            forum.metadata.tickleForFetchedResultsController()
        }
    }
}

extension IndexScrapeResult.ScrapedForum.Moderator {
    func update(_ user: User) {
        if user.userID != userID { user.userID = userID }
        if user.username != username { user.username = username }
        user.absorbPlaceholders()
    }
}

extension IndexScrapeResult.ScrapedProfile {
    func upsert(into context: NSManagedObjectContext) -> Profile {
        let user = User.findOrCreate(
            in: context,
            matching: .init(format: "%K = %@", #keyPath(User.userID), userID),
            configure: { $0.userID = userID }
        )
        update(user)
        user.absorbPlaceholders()

        let profile = user.profile ?? Profile.insert(into: context)
        if profile.user != user { profile.user = user }
        update(profile)

        return profile
    }

    func update(_ user: User) {
        if
            let canReceivePM = canReceivePrivateMessages,
            user.canReceivePrivateMessages != canReceivePM
        {
            user.canReceivePrivateMessages = canReceivePM
        }
        if user.customTitleHTML != customTitle {
            user.customTitleHTML = customTitle
        }
        if let regdate = regdate, user.regdate != regdate {
            user.regdate = regdate
        }
        if let regdateRaw = regdateRaw, user.regdateRaw != regdateRaw {
            user.regdateRaw = regdateRaw
        }
        if user.username != username {
            user.username = username
        }
    }

    func update(_ profile: Profile) {
        if let aim = aim, profile.aimName != aim {
            profile.aimName = aim
        }
        if let biography = biography, profile.aboutMe != biography {
            profile.aboutMe = biography
        }
        if let scraped = gender {
            let stored = Profile.Gender(scraped)
            if profile.gender != stored {
                profile.gender = stored
            }
        }
        if let homepage = homepage {
            let url = URL(string: homepage)
            if profile.homepageURL != url {
                profile.homepageURL = url
            }
        }
        if let icq = icq, profile.icqName != icq {
            profile.icqName = icq
        }
        if let interests = interests, profile.interests != interests {
            profile.interests = interests
        }
        if let lastPostDate = lastPostDate, profile.lastPostDate != lastPostDate  {
            profile.lastPostDate = lastPostDate
        }
        if let location = location, profile.location != location {
            profile.location = location
        }
        if let occupation = occupation, profile.occupation != occupation {
            profile.occupation = occupation
        }
        if let picture = picture {
            let url = URL(string: picture)
            if profile.profilePictureURL != url {
                profile.profilePictureURL = url
            }
        }
        if let postCount = postCount, profile.postCount != Int32(postCount) {
            profile.postCount = Int32(postCount)
        }
        if let postRate = postsPerDay.map({ String($0) }), profile.postRate != postRate {
            profile.postRate = postRate
        }
        // TODO: role?
        if let yahoo = yahoo, profile.yahooName != yahoo {
            profile.yahooName = yahoo
        }
    }
}

extension ForumMetadata {
    func tickleForFetchedResultsController() {
        let favorite = self.favorite
        self.favorite = favorite
    }
}

private extension Profile.Gender {
    init(_ scraped: IndexScrapeResult.ScrapedProfile.Gender) {
        switch scraped {
        case .female: self = .female
        case .male: self = .male
        case .porpoise: self = .porpoise
        }
    }
}
