import Foundation

/// Scripture text is the King James Version (public domain). Every reference below is a real
/// passage; reflections are original short thoughts and are not Scripture.
struct Verse: Identifiable, Hashable {
    var id: String { reference }
    let reference: String
    let text: String
    let theme: String
    let reflection: String
}

enum BibleData {
    static let themes = ["Discipline", "Perseverance", "Strength", "Faith", "Patience",
                         "Consistency", "Self-control", "Growth"]

    static let verses: [Verse] = [
        Verse(reference: "Philippians 4:13",
              text: "I can do all things through Christ which strengtheneth me.",
              theme: "Strength",
              reflection: "Strength is received before it is spent. Begin today's work by asking for it, then do the next rep."),
        Verse(reference: "Isaiah 40:31",
              text: "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
              theme: "Perseverance",
              reflection: "Rest and trust are part of training. Renewal comes to those who keep showing up and keep waiting well."),
        Verse(reference: "1 Corinthians 9:24-27",
              text: "Know ye not that they which run in a race run all, but one receiveth the prize? So run, that ye may obtain. And every man that striveth for the mastery is temperate in all things. Now they do it to obtain a corruptible crown; but we an incorruptible. I therefore so run, not as uncertainly; so fight I, not as one that beateth the air: But I keep under my body, and bring it into subjection: lest that by any means, when I have preached to others, I myself should be a castaway.",
              theme: "Discipline",
              reflection: "Train with purpose, not at random. Discipline of the body serves a larger calling than appearance."),
        Verse(reference: "Proverbs 24:16",
              text: "For a just man falleth seven times, and riseth up again: but the wicked shall fall into mischief.",
              theme: "Perseverance",
              reflection: "A missed week is not the end. What defines you is how quickly you stand back up."),
        Verse(reference: "Joshua 1:9",
              text: "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.",
              theme: "Strength",
              reflection: "Courage is not the absence of fear. Walk into the gym, the hard conversation or the early morning knowing you are not alone."),
        Verse(reference: "Galatians 6:9",
              text: "And let us not be weary in well doing: for in due season we shall reap, if we faint not.",
              theme: "Consistency",
              reflection: "Results arrive in their season. Your job today is only to keep doing the good thing."),
        Verse(reference: "James 1:2-4",
              text: "My brethren, count it all joy when ye fall into divers temptations; Knowing this, that the trying of your faith worketh patience. But let patience have her perfect work, that ye may be perfect and entire, wanting nothing.",
              theme: "Patience",
              reflection: "Plateaus and hard weeks are not detours; they are how patience is built."),
        Verse(reference: "Romans 5:3-4",
              text: "And not only so, but we glory in tribulations also: knowing that tribulation worketh patience; And patience, experience; and experience, hope:",
              theme: "Perseverance",
              reflection: "Difficulty, endured faithfully, becomes experience, and experience becomes hope."),
        Verse(reference: "2 Timothy 1:7",
              text: "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.",
              theme: "Self-control",
              reflection: "A sound mind is a trained mind. Choose the calm, deliberate option today."),
        Verse(reference: "Proverbs 25:28",
              text: "He that hath no rule over his own spirit is like a city that is broken down, and without walls.",
              theme: "Self-control",
              reflection: "Self-control is the wall that protects everything else you are building."),
        Verse(reference: "Proverbs 16:32",
              text: "He that is slow to anger is better than the mighty; and he that ruleth his spirit than he that taketh a city.",
              theme: "Self-control",
              reflection: "Real strength includes mastery of temper. The strongest man in the room is the calmest."),
        Verse(reference: "Hebrews 12:1",
              text: "Wherefore seeing we also are compassed about with so great a cloud of witnesses, let us lay aside every weight, and the sin which doth so easily beset us, and let us run with patience the race that is set before us,",
              theme: "Perseverance",
              reflection: "Lay down what slows you down. Then run your own race at your own steady pace."),
        Verse(reference: "Colossians 3:23",
              text: "And whatsoever ye do, do it heartily, as to the Lord, and not unto men;",
              theme: "Discipline",
              reflection: "Work as if no one is watching, because Someone is. Quality in private builds character in public."),
        Verse(reference: "Proverbs 13:4",
              text: "The soul of the sluggard desireth, and hath nothing: but the soul of the diligent shall be made fat.",
              theme: "Discipline",
              reflection: "Wanting is not doing. Diligence turns desire into something real."),
        Verse(reference: "Psalm 46:1",
              text: "God is our refuge and strength, a very present help in trouble.",
              theme: "Faith",
              reflection: "When training, work or life feels heavy, help is already near."),
        Verse(reference: "Psalm 27:1",
              text: "The LORD is my light and my salvation; whom shall I fear? the LORD is the strength of my life; of whom shall I be afraid?",
              theme: "Faith",
              reflection: "Fear shrinks when it is placed beside faith. Take the next step in the light you have."),
        Verse(reference: "Isaiah 41:10",
              text: "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.",
              theme: "Strength",
              reflection: "You are upheld, not just expected to cope. Lean on that today."),
        Verse(reference: "Proverbs 3:5-6",
              text: "Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
              theme: "Faith",
              reflection: "Make your plan, then hold it loosely. Direction comes to those who stay faithful in small things."),
        Verse(reference: "Psalm 18:32",
              text: "It is God that girdeth me with strength, and maketh my way perfect.",
              theme: "Strength",
              reflection: "Strength is a gift to steward. Use it to serve, not only to impress."),
        Verse(reference: "1 Corinthians 6:19-20",
              text: "What? know ye not that your body is the temple of the Holy Ghost which is in you, which ye have of God, and ye are not your own? For ye are bought with a price: therefore glorify God in your body, and in your spirit, which are God's.",
              theme: "Discipline",
              reflection: "Caring for your body — food, sleep, training — is a form of stewardship."),
        Verse(reference: "Romans 12:2",
              text: "And be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God.",
              theme: "Growth",
              reflection: "Lasting transformation starts in the mind. Change the thinking and the habits follow."),
        Verse(reference: "Proverbs 14:23",
              text: "In all labour there is profit: but the talk of the lips tendeth only to penury.",
              theme: "Consistency",
              reflection: "Less talk, more work. Profit lives in the labour."),
        Verse(reference: "Ecclesiastes 9:10",
              text: "Whatsoever thy hand findeth to do, do it with thy might; for there is no work, nor device, nor knowledge, nor wisdom, in the grave, whither thou goest.",
              theme: "Discipline",
              reflection: "Give today's task your full effort. Today is the only day you can actually work in."),
        Verse(reference: "Psalm 37:5",
              text: "Commit thy way unto the LORD; trust also in him; and he shall bring it to pass.",
              theme: "Faith",
              reflection: "Commit the work, trust the outcome."),
        Verse(reference: "Lamentations 3:22-23",
              text: "It is of the LORD'S mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.",
              theme: "Patience",
              reflection: "Yesterday's lapse does not carry over. Mercy is new this morning, and so is your chance."),
        Verse(reference: "1 Timothy 4:8",
              text: "For bodily exercise profiteth little: but godliness is profitable unto all things, having promise of the life that now is, and of that which is to come.",
              theme: "Growth",
              reflection: "Train the body well, and train the heart more. Keep both in proportion."),
        Verse(reference: "Galatians 5:22-23",
              text: "But the fruit of the Spirit is love, joy, peace, longsuffering, gentleness, goodness, faith, Meekness, temperance: against such there is no law.",
              theme: "Self-control",
              reflection: "Temperance is fruit, not just force. Ask for it as well as practise it."),
        Verse(reference: "2 Peter 1:5-6",
              text: "And beside this, giving all diligence, add to your faith virtue; and to virtue knowledge; And to knowledge temperance; and to temperance patience; and to patience godliness;",
              theme: "Growth",
              reflection: "Character is built layer by layer: virtue, knowledge, temperance, patience."),
        Verse(reference: "Psalm 90:12",
              text: "So teach us to number our days, that we may apply our hearts unto wisdom.",
              theme: "Discipline",
              reflection: "Days are limited and precious. Spend today on what matters."),
        Verse(reference: "Philippians 3:13-14",
              text: "Brethren, I count not myself to have apprehended: but this one thing I do, forgetting those things which are behind, and reaching forth unto those things which are before, I press toward the mark for the prize of the high calling of God in Christ Jesus.",
              theme: "Perseverance",
              reflection: "Leave the past week behind. Press on toward the mark with one thing in view."),
        Verse(reference: "Deuteronomy 31:6",
              text: "Be strong and of a good courage, fear not, nor be afraid of them: for the LORD thy God, he it is that doth go with thee; he will not fail thee, nor forsake thee.",
              theme: "Strength",
              reflection: "You never walk into difficulty alone."),
        Verse(reference: "Matthew 6:33",
              text: "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.",
              theme: "Faith",
              reflection: "Order your priorities and the rest finds its place."),
        Verse(reference: "Proverbs 27:17",
              text: "Iron sharpeneth iron; so a man sharpeneth the countenance of his friend.",
              theme: "Growth",
              reflection: "Train with people who make you better, and be that person for someone else."),
        Verse(reference: "2 Corinthians 4:16",
              text: "For which cause we faint not; but though our outward man perish, yet the inward man is renewed day by day.",
              theme: "Perseverance",
              reflection: "The body ages, but the inner life can be renewed daily. Tend both."),
        Verse(reference: "Psalm 28:7",
              text: "The LORD is my strength and my shield; my heart trusted in him, and I am helped: therefore my heart greatly rejoiceth; and with my song will I praise him.",
              theme: "Faith",
              reflection: "Gratitude steadies the heart. Start the day with thanks."),
        Verse(reference: "Proverbs 21:5",
              text: "The thoughts of the diligent tend only to plenty; but of every one that is hasty only to want.",
              theme: "Patience",
              reflection: "Quick fixes leave you wanting. Diligent plans compound."),
        Verse(reference: "1 Corinthians 16:13",
              text: "Watch ye, stand fast in the faith, quit you like men, be strong.",
              theme: "Strength",
              reflection: "Stay alert, stand firm, stay strong."),
        Verse(reference: "Proverbs 4:23",
              text: "Keep thy heart with all diligence; for out of it are the issues of life.",
              theme: "Self-control",
              reflection: "Guard what you let in: what you watch, read and dwell on shapes what you do."),
        Verse(reference: "Psalm 23:2-3",
              text: "He maketh me to lie down in green pastures: he leadeth me beside the still waters. He restoreth my soul: he leadeth me in the paths of righteousness for his name's sake.",
              theme: "Patience",
              reflection: "Rest is part of the path. Recovery days restore you for the work ahead."),
        Verse(reference: "Psalm 73:26",
              text: "My flesh and my heart faileth: but God is the strength of my heart, and my portion for ever.",
              theme: "Strength",
              reflection: "When your own reserves run out, there is a deeper source.")
    ]

    static func verse(for reference: String) -> Verse? {
        verses.first { $0.reference == reference }
    }

    /// Deterministic verse for a given day – one verse a day, cycling through the library.
    static func verse(on date: Date) -> Verse {
        let ordinal = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? date.dayOfYear
        return verses[ordinal % verses.count]
    }
}

enum Motivation {
    private static let lines = [
        "Show up today. Small, steady effort beats occasional intensity.",
        "You don't need a perfect day, just a faithful one.",
        "Do the next right thing, then the one after that.",
        "Consistency is quiet. It compounds while you're not looking.",
        "Train the body, guard the mind, keep the faith.",
        "Discipline is choosing what you want most over what you want now.",
        "Progress is built in ordinary days like this one.",
        "Be patient with the process and impatient with excuses.",
        "One good session, one good meal, one good decision.",
        "Strong people rest well, eat well and return tomorrow.",
        "Don't negotiate with the plan; just begin.",
        "Every rep is a vote for the person you're becoming.",
        "Start where you are. Use what you have. Do what you can.",
        "Your future self is watching what you do today."
    ]

    static func message(for date: Date = Date()) -> String {
        lines[(date.dayOfYear + Calendar.current.component(.year, from: date)) % lines.count]
    }

    static func greeting(name: String, date: Date = Date()) -> String {
        let h = Calendar.current.component(.hour, from: date)
        let part: String
        switch h {
        case 4..<12: part = "Good morning"
        case 12..<17: part = "Good afternoon"
        case 17..<22: part = "Good evening"
        default: part = "Good night"
        }
        return name.isEmpty ? part : "\(part), \(name)"
    }
}
