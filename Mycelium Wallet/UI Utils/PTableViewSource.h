#import <UIKit/UIKit.h>

@class PTableViewSourceSection;
@class PTableViewSourceItem;

// These properties are inherited by an item from section when it's added to a section using -item: method.
// Similarly, they are inherited by a section from source object when it's added to a source using -section: method.
@interface PTableViewSourceAttributes : NSObject

@property(nonatomic) NSString* cellIdentifier;
@property(nonatomic) UITableViewCellStyle cellStyle;
@property(nonatomic) UITableViewCellSelectionStyle selectionStyle;
@property(nonatomic) UITableViewCellAccessoryType accessoryType;
@property(nonatomic) UITableViewCellAccessoryType editingAccessoryType;
@property(nonatomic) NSTextAlignment textAlignment;
@property(nonatomic) CGFloat minimumScaleFactor;
@property(nonatomic) BOOL adjustsFontSizeToFitWidth;
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic) UIFont* font;
@property(nonatomic) UIFont* detailFont;
@property(nonatomic) UIColor* textColor;
@property(nonatomic) UIColor* detailTextColor;
@property(nonatomic) CGFloat rowHeight;
@property(nonatomic) UIView* inputView;
@property(nonatomic) UIView* inputAccessoryView;

// Segue is performed only if action block is nil. Sender is selected PTableViewSourceItem.
@property(nonatomic) NSString* segueIdentifier;

// Called upon selection.
@property(nonatomic, strong) void(^action)(PTableViewSourceItem* item, NSIndexPath* indexPath);

// If this block is specified, the cell is not configured with attributes. You may call setupCell: to apply them.
// If this block is nil, then -setupCell: is called automatically.
@property(nonatomic, strong) void(^setupAction)(PTableViewSourceItem* item, NSIndexPath* indexPath, UITableViewCell* cell);

// When view controller acts as a form, this block may return a label which will be replaced by a textfield.
// If block returns nil or block itself is nil, a hidden textfield is used.
// If block textFieldForEditing is not nil, this block is never called.
@property(nonatomic, strong) UILabel*(^labelForTextField)(PTableViewSourceItem* item, NSIndexPath* indexPath, UITableViewCell* cell);

// When view controller acts as a form, this block may return a textfield to edit.
// If block returns nil or block itself is nil, a hidden textfield is used.
// This block overrides labelForTextField.
@property(nonatomic, strong) UITextField*(^textFieldForEditing)(PTableViewSourceItem* item, NSIndexPath* indexPath, UITableViewCell* cell);

@property(nonatomic) NSNumber* canEditRow;
@property(nonatomic) NSNumber* canMoveRow;
@property(nonatomic, strong) NSIndexPath*(^willSelectAction)(PTableViewSourceItem* item, NSIndexPath* indexPath);
@property(nonatomic, strong) void(^insertAction)(PTableViewSourceItem* item, NSIndexPath* indexPath);
@property(nonatomic, strong) void(^deleteAction)(PTableViewSourceItem* item, NSIndexPath* indexPath);

// These have no meaning on item and never apply to it.
// You should set these for a section or a source.
@property(nonatomic, strong) void(^moveAction)(PTableViewSourceItem* item, NSIndexPath* sourceIndexPath, NSIndexPath* destinationIndexPath);
@property(nonatomic, strong) NSIndexPath*(^moveTargetBlock)(PTableViewSourceItem* item, NSIndexPath* sourceIndexPath, NSIndexPath* proposedDestinationIndexPath);

// Called internally when items or sections are added.
- (void) inheritAttributesFrom:(PTableViewSourceAttributes*)other;

@end

@interface PTableViewSource : PTableViewSourceAttributes <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, weak) UIViewController* viewController;
@property(nonatomic) NSArray* sections;

// Add ready section
- (void) addSection:(PTableViewSourceSection*) section;

// To build section within a block
- (void) section:(void(^)(PTableViewSourceSection* section))block;

// Returns sections[i]
- (PTableViewSourceSection*) sectionAtIndex:(NSInteger)sectionIndex;
- (PTableViewSourceItem*) itemAtIndexPath:(NSIndexPath*)itemIndexPath;

@end


@interface PTableViewSourceSection : PTableViewSourceAttributes

@property(nonatomic) NSArray* items;
@property(nonatomic, weak, readonly) PTableViewSource* source;

@property(nonatomic) NSString* headerTitle;
@property(nonatomic) NSString* footerTitle;
@property(nonatomic) NSString* indexTitle; // used in -sectionIndexTitlesForTableView: (NOT WORKING YET)

@property(nonatomic) UIView* headerView;
@property(nonatomic) UIView* footerView;

// Arbitrary user-provided data
@property(nonatomic) id key;
@property(nonatomic) id value;
@property(nonatomic) NSDictionary* userInfo;

+ (PTableViewSourceSection*) section:(void(^)(PTableViewSourceSection* section))block;

// Add ready item
- (void) addItem:(PTableViewSourceItem*) item;

// Build item within a block
- (void) item:(void(^)(PTableViewSourceItem* item))block;

// Returns items[i]
- (PTableViewSourceItem*) itemAtIndex:(NSInteger)itemIndex;

@end



@interface PTableViewSourceItem : PTableViewSourceAttributes

@property(nonatomic) NSString* title;
@property(nonatomic) NSString* detailTitle;

// Arbitrary user-provided data (not inherited from section)
@property(nonatomic) id key;
@property(nonatomic) id value;
@property(nonatomic) NSDictionary* userInfo;

@property(nonatomic, weak, readonly) PTableViewSourceSection* section;

+ (PTableViewSourceItem*) item:(void(^)(PTableViewSourceItem* section))block;

// Applies properties to the cell.
- (void) setupCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath;

@end

