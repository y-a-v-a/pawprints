import Foundation

// Hand-written content tables. The engine combines these into a case, so every
// combination has to read well. The model never invents facts, only voices them.

/// A physical trace a suspect can leave at the scene. Several suspects share each
/// trace, which is what makes the "means" clue ambiguous until testimony narrows it.
public enum Trace: String, Codable, Sendable, CaseIterable {
    case russetFur, greyFur, whiteFur, feather, pipeAsh, gardenSoil, flour, ink, perfume, damp, spine, sawdust

    public var clue: String {
        switch self {
        case .russetFur: "a few russet-red hairs snagged on the velvet cushion"
        case .greyFur: "a tuft of soft grey fur caught on the cabinet hinge"
        case .whiteFur: "fine white fur clinging to the dark velvet lining"
        case .feather: "a long feather lying beneath the open cabinet"
        case .pipeAsh: "a pinch of pipe ash scattered on the carpet"
        case .gardenSoil: "crumbs of fresh garden soil tracked across the rug"
        case .flour: "a dusting of flour on the cabinet handle"
        case .ink: "an inky smudge on the glass"
        case .perfume: "the lingering scent of violet perfume"
        case .damp: "a trail of damp, webbed footprints"
        case .spine: "a single prickly spine wedged in the doorframe"
        case .sawdust: "a sprinkle of fine sawdust on the windowsill"
        }
    }

    public var title: String {
        switch self {
        case .russetFur: "Russet hairs"
        case .greyFur: "Grey fur"
        case .whiteFur: "White fur"
        case .feather: "A feather"
        case .pipeAsh: "Pipe ash"
        case .gardenSoil: "Garden soil"
        case .flour: "Flour"
        case .ink: "Inky smudge"
        case .perfume: "Violet perfume"
        case .damp: "Damp footprints"
        case .spine: "A prickly spine"
        case .sawdust: "Sawdust"
        }
    }

    /// What it tells the inspector, phrased as the notebook would.
    public var meaning: String {
        switch self {
        case .russetFur: "Someone with russet fur was at the cabinet."
        case .greyFur: "Someone with grey fur was at the cabinet."
        case .whiteFur: "Someone with white fur was at the cabinet."
        case .feather: "A bird has been at the cabinet."
        case .pipeAsh: "A pipe smoker stood by the cabinet."
        case .gardenSoil: "Someone came in straight from digging."
        case .flour: "Someone came from baking or the kitchen."
        case .ink: "Someone with ink on them touched the glass."
        case .perfume: "Someone wearing violet perfume was here."
        case .damp: "Someone with wet, webbed feet came through."
        case .spine: "A hedgehog brushed past the door."
        case .sawdust: "Someone who works with wood was here."
        }
    }

    public var illustration: String {
        switch self {
        case .russetFur: "a few russet red animal hairs on a purple velvet cushion, close-up"
        case .greyFur: "a tuft of soft grey fur caught on a brass cabinet hinge, close-up"
        case .whiteFur: "a few strands of white fur on dark blue velvet fabric, close-up, no animals"
        case .feather: "a long feather on a patterned carpet beneath an open glass cabinet"
        case .pipeAsh: "a small pile of pipe ash on an ornate carpet, close-up"
        case .gardenSoil: "crumbs of dark garden soil on a fancy rug, close-up"
        case .flour: "white flour dust on a brass cabinet handle, close-up"
        case .ink: "black ink paw prints on a glass display case"
        case .perfume: "a small violet perfume bottle with violets, still life"
        case .damp: "wet webbed footprints on polished floorboards"
        case .spine: "a single sharp brown quill stuck in a wooden doorframe, close-up, no animals"
        case .sawdust: "fine sawdust sprinkled on a windowsill, close-up"
        }
    }
}

public struct CharacterTemplate: Sendable {
    public let name: String
    public let shortName: String
    public let species: String
    public let occupation: String
    public let isStaff: Bool
    public let personality: String
    public let voice: String
    public let look: String
    public let traces: [Trace]
    /// Lines the engine can use when the model can't, or won't, answer.
    public let deflections: [String]
    public let isFemale: Bool
    /// What players might call them instead of their name ("the doctor", "the maid").
    public var nicknames: [String] = []
    /// Little openers in their own voice, added now and then for colour.
    public var catchphrases: [String] = []
}

public enum Cast {
    public static let all: [CharacterTemplate] = [
        .init(name: "Dr. Reynard Ashby", shortName: "Dr. Ashby", species: "fox",
              occupation: "the village doctor", isStaff: false,
              personality: "smooth, charming and a little too quick with an answer",
              voice: "polished, honeyed sentences; calls people \"my dear fellow\"",
              look: "a handsome fox in a tweed suit and waistcoat, holding a black doctor's bag",
              traces: [.russetFur, .pipeAsh],
              deflections: ["Come now, my dear fellow, let's keep this civilised.", "I'm a doctor, not a gossip. Next question."], isFemale: false,
              nicknames: ["doctor", "doc"], catchphrases: ["My dear fellow,", "Ah,", "Now, now,"]),
        .init(name: "Agnes Whiskerton", shortName: "Agnes", species: "mouse",
              occupation: "the housemaid", isStaff: true,
              personality: "timid, eager to please and easily flustered",
              voice: "quick and breathless; says \"begging your pardon\" and apologises a lot",
              look: "a small grey mouse housemaid in a white lace cap and frilly apron",
              traces: [.greyFur, .flour],
              deflections: ["Oh! Begging your pardon, I don't know anything about that.", "I-I'd rather not say, if it's all the same to you."], isFemale: true,
              nicknames: ["maid", "housemaid"], catchphrases: ["Oh! Begging your pardon,", "Oh dear,", "Sorry, sorry,"]),
        .init(name: "Colonel Barnaby Brock", shortName: "the Colonel", species: "badger",
              occupation: "a retired army colonel", isStaff: false,
              personality: "gruff, blustering and very proud",
              voice: "clipped barks, military slang, the odd \"harrumph\"",
              look: "an old badger wearing a red army jacket with shiny brass medals",
              traces: [.pipeAsh, .gardenSoil],
              deflections: ["Harrumph! I'll not dignify that with an answer.", "Steady on, Inspector. Mind your manners."], isFemale: false,
              nicknames: ["colonel", "soldier"], catchphrases: ["Harrumph!", "Now see here,", "In my day,"]),
        .init(name: "Lady Imelda Heronsgate", shortName: "Lady Heronsgate", species: "heron",
              occupation: "a society grande dame", isStaff: false,
              personality: "haughty, imperious and easily bored",
              voice: "icy politeness and long, elegant words",
              look: "a tall grey heron with a pearl necklace and a feathered hat",
              traces: [.feather, .perfume],
              deflections: ["How very vulgar. I shan't answer that.", "Inspector, really. Do try to keep up."], isFemale: true,
              nicknames: ["lady", "dame"], catchphrases: ["How tiresome.", "My dear Inspector,", "Really,"]),
        .init(name: "Pip Thistledown", shortName: "Pip", species: "hedgehog",
              occupation: "the gardener", isStaff: true,
              personality: "shy, gentle and slow to speak",
              voice: "short mumbled sentences in a soft country burr; says \"aye\" and talks about plants",
              look: "a shy hedgehog gardener in a flat cap and muddy apron, holding a trowel",
              traces: [.gardenSoil, .spine],
              deflections: ["Aye... I'd not know about that, sir.", "Best ask someone else, I reckon."], isFemale: false,
              nicknames: ["gardener"], catchphrases: ["Aye,", "Well now,", "Mm,"]),
        .init(name: "Mrs. Wilhelmina Otterly", shortName: "Mrs. Otterly", species: "otter",
              occupation: "the cook", isStaff: true,
              personality: "jolly, warm and an incorrigible gossip",
              voice: "chatty and motherly; calls everyone \"dearie\" and mentions food",
              look: "a plump, cheerful otter cook in a white apron and cap, holding a wooden spoon",
              traces: [.flour, .damp],
              deflections: ["Ooh, dearie, that's not the sort of thing I talk about.", "Have a scone and ask me something nicer."], isFemale: true,
              nicknames: ["cook"], catchphrases: ["Ooh, dearie,", "Bless you,", "Well, dearie,"]),
        .init(name: "Percival Hopworth", shortName: "Mr. Hopworth", species: "rabbit",
              occupation: "the private secretary", isStaff: true,
              personality: "anxious, precise and fussy",
              voice: "fussy, exact sentences; he corrects small details and loves proper procedure",
              look: "a nervous white rabbit secretary in a waistcoat and spectacles, clutching a ledger",
              traces: [.ink, .whiteFur],
              deflections: ["That is, ah, quite outside my remit, Inspector.", "I really couldn't comment. Not officially."], isFemale: false,
              nicknames: ["secretary", "clerk"], catchphrases: ["Ahem.", "Strictly for the record,", "If I may,"]),
        .init(name: "Professor Hortensia Hoots", shortName: "the Professor", species: "owl",
              occupation: "a visiting professor of history", isStaff: false,
              personality: "pedantic, absent-minded and fond of lecturing",
              voice: "long-winded, scholarly, and she corrects people's grammar",
              look: "a wise brown owl with spectacles, sitting on a pile of books",
              traces: [.feather, .ink],
              deflections: ["A most improper question, Inspector. Improper and ungrammatical.", "History will judge that question harshly."], isFemale: true,
              nicknames: ["professor", "prof"], catchphrases: ["Hmm, yes.", "Historically speaking,", "Ahem,"]),
        .init(name: "Mr. Corvin Blackwood", shortName: "Mr. Blackwood", species: "crow",
              occupation: "an antiques dealer", isStaff: false,
              personality: "sly, silky and covetous",
              voice: "smooth and silky; he mentions what things are worth",
              look: "a sly black crow wearing a velvet waistcoat, peering through a jeweller's loupe",
              traces: [.feather, .sawdust],
              deflections: ["Some questions are priceless, Inspector. That one is worthless.", "I deal in antiques, not accusations."], isFemale: false,
              nicknames: ["dealer", "antiques"], catchphrases: ["Ah,", "Now, Inspector,", "How curious,"]),
        .init(name: "Countess Felicity Purrington", shortName: "the Countess", species: "cat",
              occupation: "a famous opera singer", isStaff: false,
              personality: "dramatic, vain and theatrical",
              voice: "grand exclamations; calls people \"darling\"",
              look: "a glamorous white Persian cat wearing a feather boa and a sparkling necklace",
              traces: [.whiteFur, .perfume],
              deflections: ["Darling, how utterly tedious. Ask me about my aria instead.", "I simply refuse to dignify that, darling."], isFemale: true,
              nicknames: ["singer", "diva"], catchphrases: ["Darling,", "Oh, darling!", "Mon dieu,"]),
        .init(name: "Hazel Nutley", shortName: "Miss Nutley", species: "squirrel",
              occupation: "a reporter for the Mossbury Gazette", isStaff: false,
              personality: "quick, nosy and cheeky",
              voice: "rapid-fire and breezy; she fires questions back",
              look: "a bright-eyed red squirrel newspaper reporter in a press hat with a notepad and pencil",
              traces: [.russetFur, .ink],
              deflections: ["Off the record? No comment. On the record? Also no comment.", "Nice try, Inspector. Next!"], isFemale: true,
              nicknames: ["reporter", "journalist"], catchphrases: ["Ooh,", "Off the record?", "Right, so,"]),
        .init(name: "Bartholomew Wartle", shortName: "Mr. Wartle", species: "toad",
              occupation: "the family solicitor", isStaff: false,
              personality: "pompous, legalistic and long-winded",
              voice: "formal legal phrases such as \"strictly speaking\" and \"heretofore\"",
              look: "a pompous toad solicitor in a black frock coat and top hat, holding a briefcase",
              traces: [.damp, .pipeAsh],
              deflections: ["I must advise myself not to answer that.", "Strictly speaking, that question is inadmissible."], isFemale: false,
              nicknames: ["solicitor", "lawyer"], catchphrases: ["Strictly speaking,", "Ahem.", "For the record,"]),
        .init(name: "Montgomery Delve", shortName: "Mr. Delve", species: "mole",
              occupation: "a wealthy mining magnate", isStaff: false,
              personality: "brusque, short-sighted and rich",
              voice: "blunt and impatient; he talks about money",
              look: "a stout mole in a pinstripe suit with tiny round spectacles and a gold watch chain",
              traces: [.gardenSoil, .greyFur],
              deflections: ["Time is money, Inspector, and you're wasting both.", "Hmph. Ask my lawyer."], isFemale: false,
              nicknames: ["magnate", "miner"], catchphrases: ["Hmph.", "Look here,", "Bottom line,"]),
        .init(name: "Captain Horace Mallard", shortName: "the Captain", species: "duck",
              occupation: "a retired riverboat captain", isStaff: false,
              personality: "hearty, boastful and fond of tall tales",
              voice: "booming nautical talk: \"shipshape\", \"ahoy\", \"blow me down\"",
              look: "a hearty mallard duck in a navy captain's coat and peaked cap, with a spyglass",
              traces: [.feather, .damp],
              deflections: ["Blow me down, that's no question for a gentleman!", "I'll not be keelhauled with questions like that."], isFemale: false,
              nicknames: ["captain", "skipper"], catchphrases: ["Ahoy!", "Blow me down,", "Shipshape, Inspector,"]),
    ]
}

public enum RoomRole: String, Codable, Sendable, CaseIterable {
    case display, gathering, quiet, kitchen, garden, cloakroom
}

public struct RoomTemplate: Sendable {
    public let role: RoomRole
    public let name: String
    public let look: String
}

public struct SettingTemplate: Sendable {
    public let place: String
    public let occasion: String
    /// Completes "…the item vanished ___".
    public let window: String
    public let rooms: [RoomTemplate]
    public let items: [(name: String, look: String)]
    public let owner: (name: String, species: String, description: String, look: String, isFemale: Bool)
    public let look: String
}

public enum Settings {
    public static let all: [SettingTemplate] = [
        .init(place: "Thornbury Hall", occasion: "the Harvest Ball",
              window: "while the lamps were out for the fireworks",
              rooms: [
                .init(role: .display, name: "the Study", look: "a wood-panelled study with a glass display cabinet standing open"),
                .init(role: .gathering, name: "the Ballroom", look: "a grand ballroom with chandeliers and tall windows lit by fireworks"),
                .init(role: .quiet, name: "the Library", look: "a cosy library with a crackling fire and towering bookshelves"),
                .init(role: .kitchen, name: "the Kitchen", look: "a warm country-house kitchen with copper pans and a big range"),
                .init(role: .garden, name: "the Conservatory", look: "a glass conservatory full of ferns and orchids at night"),
                .init(role: .cloakroom, name: "the Cloakroom", look: "a narrow cloakroom crowded with coats, hats and umbrellas"),
              ],
              items: [("the Midsummer Emerald", "a huge glittering green emerald on a velvet cushion"),
                      ("the Thornbury Tiara", "a sparkling silver tiara set with sapphires on a velvet stand")],
              owner: ("Lord Algernon Thornbury", "stag", "the elderly stag who owns Thornbury Hall", "an old stag with big antlers wearing a velvet smoking jacket", false),
              look: "a grand English country manor house at night with fireworks over the roof"),
        .init(place: "the Willowbrook Village Show", occasion: "the prize-giving",
              window: "during the brass band's grand finale",
              rooms: [
                .init(role: .display, name: "the Prize Marquee", look: "a white canvas marquee with trestle tables of prize vegetables and an empty trophy stand"),
                .init(role: .gathering, name: "the Bandstand Lawn", look: "a village green with a bunting-draped bandstand and shiny brass trumpets resting on chairs"),
                .init(role: .quiet, name: "the Vicarage Study", look: "a cluttered vicarage study with sermons and a ticking clock"),
                .init(role: .kitchen, name: "the Tea Tent", look: "a tea tent with urns, scones and rows of cakes under glass domes"),
                .init(role: .garden, name: "the Allotments", look: "neat vegetable allotments with marrows and a garden shed at dusk"),
                .init(role: .cloakroom, name: "the Exhibitors' Tent", look: "a small tent piled with coats, baskets and exhibitors' boxes"),
              ],
              items: [("the Golden Acorn Trophy", "a shining golden acorn trophy on a wooden plinth"),
                      ("the Silver Marrow Cup", "a polished silver cup engraved with a marrow")],
              owner: ("the Reverend Hubert Oakley", "tortoise", "the kindly old tortoise who runs the village show", "a kindly old tortoise wearing a black jacket, a white collar and round glasses", false),
              look: "an English village show with bunting, a white marquee and a bandstand at golden hour"),
        .init(place: "the Bramblewood Inn", occasion: "the Midwinter Supper",
              window: "while everyone sang carols around the piano",
              rooms: [
                .init(role: .display, name: "the Snug", look: "a snug inn room with a small glass cabinet above the fireplace, its door ajar"),
                .init(role: .gathering, name: "the Parlour", look: "a cosy inn parlour with a piano, evergreen garlands and candles"),
                .init(role: .quiet, name: "the Reading Nook", look: "a quiet reading nook under the eaves with an armchair and a lamp"),
                .init(role: .kitchen, name: "the Kitchen", look: "an inn kitchen with steaming puddings and strings of onions"),
                .init(role: .garden, name: "the Stables", look: "snowy stables with lanterns, hay bales and a sleepy pony"),
                .init(role: .cloakroom, name: "the Boot Room", look: "a boot room full of snowy boots, scarves and winter coats"),
              ],
              items: [("Old Mother Hedgely's Pudding Recipe", "an old handwritten recipe card in a little tin box"),
                      ("the Bramblewood Silver Tankard", "an antique silver tankard engraved with brambles")],
              owner: ("Mrs. Rosamund Hedgely", "hedgehog", "the hedgehog landlady of the Bramblewood Inn", "a round, rosy hedgehog landlady in a shawl", true),
              look: "a snowed-in country inn at night with glowing windows and a wreath on the door"),
        .init(place: "the riverboat Marigold", occasion: "the Moonlight Cruise",
              window: "as the boat drifted under Kingfisher Bridge in the fog",
              rooms: [
                .init(role: .display, name: "the Captain's Cabin", look: "a riverboat captain's cabin with brass fittings and an open display case"),
                .init(role: .gathering, name: "the Grand Saloon", look: "a riverboat saloon with lanterns, a piano and a polished dance floor"),
                .init(role: .quiet, name: "the Reading Room", look: "a small wood-panelled reading room on a riverboat with a porthole"),
                .init(role: .kitchen, name: "the Galley", look: "a small ship's kitchen with copper pots bubbling on a stove and round portholes"),
                .init(role: .garden, name: "the Promenade Deck", look: "a misty riverboat deck at night with strings of lights and potted plants"),
                .init(role: .cloakroom, name: "the Cloak Cupboard", look: "a cupboard full of cloaks, life rings and umbrellas"),
              ],
              items: [("the Duchess's Pearl Music Box", "an ornate music box inlaid with pearls"),
                      ("the Marigold's Brass Chronometer", "a gleaming brass ship's chronometer in a wooden case")],
              owner: ("the Duchess of Fernley", "swan", "the formidable old swan who owns the Marigold", "a formidable elderly swan duchess in a lace shawl and tiara", true),
              look: "a paddle-steamer riverboat on a misty river at night with glowing lanterns"),
        .init(place: "the Mossbury Museum", occasion: "Lantern Night",
              window: "during the lantern parade",
              rooms: [
                .init(role: .display, name: "the Hall of Curiosities", look: "a museum hall of curiosities with an empty glass case on a pedestal"),
                .init(role: .gathering, name: "the Terrace", look: "a stone museum terrace at night with paper lanterns floating by"),
                .init(role: .quiet, name: "the Map Room", look: "a museum map room with globes, old charts and a reading lamp"),
                .init(role: .kitchen, name: "the Tea Room", look: "a museum tea room with cake stands and teapots"),
                .init(role: .garden, name: "the Fossil Garden", look: "a moonlit garden with stone fossils and dinosaur topiary"),
                .init(role: .cloakroom, name: "the Cloakroom", look: "a museum cloakroom with rows of numbered coat hooks"),
              ],
              items: [("the Clockwork Nightingale", "a delicate golden clockwork nightingale"),
                      ("the Moonstone Egg", "a glowing pale blue moonstone egg on a silver stand")],
              owner: ("Curator Ignatius Quill", "porcupine", "the fastidious porcupine curator of the Mossbury Museum", "a fastidious old porcupine curator in a bow tie and monocle", false),
              look: "a grand old museum building at night with paper lanterns floating in the sky"),
    ]
}

/// Why the thief did it. `{c}` is the culprit, `{owner}` the victim, `{item}` the stolen item.
public struct MotiveTemplate: Sendable {
    public let summary: String
    public let gossip: String
    /// Words a retelling of the gossip must keep, so it can't drift into something else.
    public let gossipKeys: [String]
    public let documentTitle: String
    public let document: String
    public let documentLook: String
    public let confession: String
}

public enum Motives {
    public static let all: [MotiveTemplate] = [
        .init(summary: "is secretly deep in debt to a riverside moneylender",
              gossip: "{c} has been terribly short of money lately. Even tried to borrow from me last week",
              gossipKeys: ["money"],
              documentTitle: "Moneylender's letter",
              document: "A moneylender's letter in {c}'s coat pocket, demanding forty gold crowns by Friday, \u{201C}or else\u{201D}.",
              documentLook: "a stern handwritten letter on yellow paper with a red wax seal, poking out of a coat pocket",
              confession: "the moneylenders were at my door, and I was desperate"),
        .init(summary: "believes {item} was swindled from the family years ago",
              gossip: "{c} is forever grumbling that {item} was swindled from the family years ago",
              gossipKeys: ["swindled"],
              documentTitle: "Family letter",
              document: "An old family letter in {c}'s coat, claiming {item} belongs to the family \u{201C}by right\u{201D}.",
              documentLook: "an old yellowed family letter tied with faded ribbon, tucked in a coat",
              confession: "it was my grandmother's, and I only took back what was ours"),
        .init(summary: "has never forgiven {owner} for laughing at {cObj} at the spring fair",
              gossip: "Ever since {owner} laughed at {c} at the spring fair, there's been bad blood between those two",
              gossipKeys: ["fair"],
              documentTitle: "Torn newspaper clipping",
              document: "A crumpled clipping in {c}'s coat: \u{201C}{c} Humiliated at Spring Fair\u{201D}, with the face scratched out.",
              documentLook: "a crumpled old newspaper clipping with a scribbled-out photograph",
              confession: "after what {owner} did to me at the spring fair, I wanted {oObj} to know how it feels to lose something"),
        .init(summary: "has a secret buyer waiting at the Old Mill",
              gossip: "I overheard {c} whispering about \u{2018}the delivery\u{2019} and \u{2018}the Old Mill\u{2019} to someone at the gate",
              gossipKeys: ["mill"],
              documentTitle: "Note about the Old Mill",
              document: "A note in {c}'s coat: \u{201C}Bring it to the Old Mill at midnight. Payment as agreed. —X\u{201D}",
              documentLook: "a small folded note written in spidery ink beside a candle",
              confession: "a buyer offered me a small fortune, and I couldn't refuse"),
        .init(summary: "has coveted {item} for years",
              gossip: "{c} couldn't stop staring at {item} all evening. Kept asking what it was worth",
              gossipKeys: ["worth"],
              documentTitle: "Scrapbook of sketches",
              document: "A scrapbook page in {c}'s coat, covered in loving sketches of {item}.",
              documentLook: "an open scrapbook covered in pencil sketches of a treasure",
              confession: "I have dreamed of owning it for years. I simply had to have it"),
    ]
}

/// The red herring's innocent but embarrassing reason for lying about where they were.
public struct SecretTemplate: Sendable {
    public let room: RoomRole
    /// A word the confession must keep, so the model can't turn it into something else.
    public let keyword: String
    public let summary: String
    public let confession: String
    public let evidenceTitle: String
    public let evidence: String
    public let evidenceLook: String
}

public enum Secrets {
    public static let all: [SecretTemplate] = [
        .init(room: .kitchen, keyword: "trifle",
              summary: "sneaked off to eat the trifle meant for pudding",
              confession: "I sneaked into {room} and ate the whole trifle meant for pudding. Every last spoonful",
              evidenceTitle: "Empty trifle bowl",
              evidence: "A trifle bowl in {room}, scraped completely clean, with a spoon still in it.",
              evidenceLook: "an empty glass trifle bowl scraped clean with a spoon in it, on a kitchen table"),
        .init(room: .garden, keyword: "sweetheart",
              summary: "was meeting a secret sweetheart",
              confession: "I was meeting my sweetheart in {room}. Nobody knows about us, and I'd like to keep it that way",
              evidenceTitle: "Two cups and a rose",
              evidence: "Two cups of cocoa and a pressed rose left side by side in {room}.",
              evidenceLook: "two cups of cocoa and a single red rose on a garden bench at night"),
        .init(room: .garden, keyword: "poem",
              summary: "was secretly rehearsing an after-supper poem",
              confession: "I was in {room} practising a poem I'd written for the toast. It's dreadful, and I was too embarrassed to say",
              evidenceTitle: "Crumpled poem",
              evidence: "Crumpled pages of a poem in {room}, every other line crossed out.",
              evidenceLook: "crumpled handwritten poem pages with many crossings-out on the ground"),
        .init(room: .cloakroom, keyword: "novel",
              summary: "was hiding in the coats to finish a racy romance novel",
              confession: "I was hiding in {room} finishing a romance novel. \"The Pirate's Passion\". I simply had to know how it ended",
              evidenceTitle: "Romance novel",
              evidence: "A dog-eared romance novel, \"The Pirate's Passion\", tucked behind the coats in {room}.",
              evidenceLook: "a dog-eared romance novel with a sailing ship and a red heart on the cover, hidden among coats"),
        .init(room: .kitchen, keyword: "cards",
              summary: "was secretly playing cards with the kitchen staff and losing badly",
              confession: "I was in {room} playing cards with the staff for buttons. I lost every button I own",
              evidenceTitle: "Playing cards and buttons",
              evidence: "A scattered deck of playing cards and a heap of buttons on the table in {room}.",
              evidenceLook: "scattered playing cards and a heap of colourful buttons on a wooden kitchen table"),
    ]
}

/// Where the thief stashed the loot, revealed in the finale, and what a careful search of
/// that room notices. `{room}` is filled per role.
public enum HidingPlaces {
    public static let all: [(role: RoomRole, text: String, hint: String)] = [
        (.cloakroom, "tucked inside a hatbox in {room}", "one hatbox has been moved, and its lid sits askew."),
        (.kitchen, "hidden in a big brown teapot in {room}", "a big brown teapot is far too heavy to be holding only tea."),
        (.garden, "buried in a flowerpot in {room}", "the soil in one flowerpot has been freshly turned."),
        (.gathering, "stuffed inside a cushion {room}", "one cushion has been unpicked and clumsily sewn up again."),
        (.quiet, "hollowed into a fat old book {room}", "a fat old book sits on the shelf upside down."),
    ]
}

/// What the loner was doing alone, when the loner isn't in the quiet room.
public enum SolitaryPursuits {
    public static let byRoom: [RoomRole: String] = [
        .kitchen: "making a quiet cup of cocoa",
        .garden: "getting some fresh air",
    ]
}
